// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BaseFacet.sol";
import "../libraries/LibAppStorage.sol";

    error Admin__InvalidDifficulty();

/**
 * @title System Administration Facet
 * @author 0xAvp
 * @notice Centralized facet handling all governance and configuration parameters.
 * @dev Inherits from BaseFacet. All state-modifying functions must be restricted via onlyOwner.
 */
contract AdminFacet is BaseFacet {

    event ChainConfigUpdated(uint64 indexed chainId, uint256 difficulty, uint256 targetBalance);
    event WithdrawFeeUpdated(uint256 oldFee, uint256 newFee);
    event DflTokenUpdated(address oldToken, address newToken);
    event PauseStateChanged(bool isPaused);

    /**
     * @notice Configures base difficulty and target liquidity of a specific network
     * @param _chainId The EVM or CCIP chain selector
     * @param _difficulty Base difficulty multiplier (e.g. 100 = 1.0x, 500 = 5.0x)
     * @param _targetBalance Desired native gas reserves in the pool (in wei)
     */
    function setChainConfig(uint64 _chainId, uint256 _difficulty, uint256 _targetBalance) external onlyOwner {
        LibAppStorage.AppStorage storage s = LibAppStorage.layout();
        s.chainDifficulties[_chainId] = _difficulty;
        s.targetBalances[_chainId] = _targetBalance;

        emit ChainConfigUpdated(_chainId, _difficulty, _targetBalance);
    }

    /**
     * @notice Configures base withdrawal fee (spread)
     * @param _fee Fee multiplier (e.g., 500 = 5.00% based on 10,000 basis points)
     */
    function setWithdrawFee(uint256 _fee) external onlyOwner {
        LibAppStorage.AppStorage storage s = LibAppStorage.layout();
        uint256 oldFee = s.withdrawFee;
        s.withdrawFee = _fee;

        emit WithdrawFeeUpdated(oldFee, _fee);
    }

    /**
     * @notice Configures the core DFL token address in AppStorage
     * @param _dflToken The address of the DFLToken contract
     */
    function setDflToken(address _dflToken) external onlyOwner {
        LibAppStorage.AppStorage storage s = LibAppStorage.layout();
        address oldToken = s.dflToken;
        s.dflToken = _dflToken;

        emit DflTokenUpdated(oldToken, _dflToken);
    }

    /**
     * @notice Globally pauses or unpauses all user-facing DeFi interactions
     * @param _paused True to pause the system, false to resume operations
     */
    function setPaused(bool _paused) external onlyOwner {
        LibAppStorage.AppStorage storage s = LibAppStorage.layout();
        s.paused = _paused;

        emit PauseStateChanged(_paused);
    }
}