// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BaseFacet.sol";
import "../libraries/LibAppStorage.sol";
import "../interfaces/IDFLToken.sol";

    error Portal__ZeroDeposit();
    error Portal__ZeroRedeem();
    error Portal__ChainNotConfigured();
    error Portal__BridgeNotConnected();
    error Portal__InsufficientPoolLiquidity();

/**
 * @title Liquidity Portal Facet
 * @author 0xAvp
 * @notice Handles native gas deposits in exchange for DFL, and DFL burns for native gas.
 * @dev Inherits from BaseFacet. Focuses strictly on user interactions and quotes.
 */
contract LiquidityPortalFacet is BaseFacet {

    event GasDeposited(address indexed user, uint256 ethAmount, uint256 dflAmount, uint256 effectiveDifficulty);
    event GasRedeemedLocal(address indexed user, uint256 dflAmount, uint256 ethAmount, uint256 effectiveDifficulty);

    /**
     * @notice Deposits native gas and mints proportional DFL tokens based on scarcity math
     */
    function depositGas() external payable whenNotPaused nonReentrant {
        uint256 depositAmount = msg.value;
        if (depositAmount == 0) revert Portal__ZeroDeposit();

        LibAppStorage.AppStorage storage s = LibAppStorage.layout();
        uint64 chainId = uint64(block.chainid);

        uint256 baseDiff = s.chainDifficulties[chainId];
        if (baseDiff == 0) revert Portal__ChainNotConfigured();

        uint256 targetBal = s.targetBalances[chainId];
        uint256 currentBal = address(this).balance - depositAmount;

        uint256 effectiveDiff = baseDiff;

        if (currentBal < targetBal && targetBal > 0) {
            uint256 deficit = targetBal - currentBal;
            uint256 deficitRatio = (deficit * 1e18) / targetBal;
            effectiveDiff = baseDiff + (baseDiff * deficitRatio) / 1e18;
        }

        uint256 dflAmount = (depositAmount * effectiveDiff) / 100;

        emit GasDeposited(msg.sender, depositAmount, dflAmount, effectiveDiff);

        IDFLToken(s.dflToken).mint(msg.sender, dflAmount);
    }

    /**
     * @notice Redeems DFL tokens for native gas, either locally or cross-chain via CCIP
     */
    function redeemGas(
        uint64 _destinationChainSelector,
        uint256 _dflAmount
    ) external payable whenNotPaused nonReentrant {
        if (_dflAmount == 0) revert Portal__ZeroRedeem();

        LibAppStorage.AppStorage storage s = LibAppStorage.layout();

        // 1. Burn user's DFL tokens first
        IDFLToken(s.dflToken).burnFrom(msg.sender, _dflAmount);

        if (_destinationChainSelector == 0) {
            // ==========================================
            // LOCAL REDEEM
            // ==========================================
            uint64 chainId = uint64(block.chainid);
            uint256 effectiveDiff = _getWithdrawDifficulty(chainId, s);

            uint256 gasAmount = (_dflAmount * 100) / effectiveDiff;

            if (address(this).balance < gasAmount) revert Portal__InsufficientPoolLiquidity();

            emit GasRedeemedLocal(msg.sender, _dflAmount, gasAmount, effectiveDiff);

            payable(msg.sender).transfer(gasAmount);
        } else {
            // ==========================================
            // CROSS-CHAIN REDEEM (CCIP)
            // ==========================================
            revert Portal__BridgeNotConnected();
        }
    }

    /**
     * @notice Helper function for frontend to query expected DFL payout and current deposit difficulty
     */
    function getDflValue(uint256 _amount) external view returns (uint256 dflAmount, uint256 effectiveDiff) {
        LibAppStorage.AppStorage storage s = LibAppStorage.layout();
        uint64 chainId = uint64(block.chainid);

        uint256 baseDiff = s.chainDifficulties[chainId];
        if (baseDiff == 0) return (0, 0);

        uint256 targetBal = s.targetBalances[chainId];
        uint256 currentBal = address(this).balance;

        effectiveDiff = baseDiff;

        if (currentBal < targetBal && targetBal > 0) {
            uint256 deficit = targetBal - currentBal;
            uint256 deficitRatio = (deficit * 1e18) / targetBal;
            effectiveDiff = baseDiff + (baseDiff * deficitRatio) / 1e18;
        }

        dflAmount = (_amount * effectiveDiff) / 100;
    }

    /**
     * @notice Helper function for frontend to query expected native gas return and current withdraw difficulty
     */
    function getGasValue(uint256 _dflAmount) external view returns (uint256 gasAmount, uint256 effectiveDiff) {
        LibAppStorage.AppStorage storage s = LibAppStorage.layout();
        uint64 chainId = uint64(block.chainid);

        effectiveDiff = _getWithdrawDifficulty(chainId, s);
        if (effectiveDiff == 0) return (0, 0);

        gasAmount = (_dflAmount * 100) / effectiveDiff;
    }

    /**
     * @notice Returns the configuration of a specific network
     * @param _chainId The chain identifier
     * @return difficulty Base difficulty multiplier
     * @return targetBalance Target pool balance in wei
     */
    function getChainConfig(uint64 _chainId) external view returns (uint256 difficulty, uint256 targetBalance) {
        LibAppStorage.AppStorage storage s = LibAppStorage.layout();
        return (s.chainDifficulties[_chainId], s.targetBalances[_chainId]);
    }

    /**
     * @notice Internal helper to calculate effective withdraw difficulty (including spread)
     */
    function _getWithdrawDifficulty(
        uint64 _chainId,
        LibAppStorage.AppStorage storage s
    ) internal view returns (uint256 effectiveDiff) {
        uint256 baseDiff = s.chainDifficulties[_chainId];
        if (baseDiff == 0) return 0;

        uint256 targetBal = s.targetBalances[_chainId];
        uint256 currentBal = address(this).balance;

        effectiveDiff = baseDiff;

        if (currentBal < targetBal && targetBal > 0) {
            uint256 deficit = targetBal - currentBal;
            uint256 deficitRatio = (deficit * 1e18) / targetBal;
            effectiveDiff = baseDiff + (baseDiff * deficitRatio) / 1e18;
        }

        uint256 penalty = s.withdrawFee;
        if (penalty > 0) {
            effectiveDiff = effectiveDiff + (effectiveDiff * penalty) / 10000;
        }
    }

}