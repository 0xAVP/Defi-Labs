// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./BaseFacet.sol";
import "../libraries/LibAppStorage.sol";
import "../libraries/LibPoolMath.sol";

    error SwapInbound__PoolNotConfigured();
    error SwapInbound__AlreadyProcessed();
    error SwapInbound__InsufficientLiquidity();
    error SwapInbound__GasExceedsPayout();
    error SwapInbound__InsufficientFeePool();
    error SwapInbound__RelayerRefundFailed();
    error SwapInbound__UserPayoutFailed();

/**
 * @title Swap Inbound Facet
 * @author 0xAvp
 * @notice Handles inbound cross-chain swap executions, relayer gas refunds, and swap cancellations.
 * @dev Inherits from BaseFacet. Restricted to the authorized relayer address.
 */
contract SwapInboundFacet is BaseFacet {

    event SwapPaidOut(bytes32 indexed swapId, address indexed user, uint256 grossAmount, uint256 gasCost);
    event SwapCancelled(bytes32 indexed swapId, uint256 gasCost);

    /**
     * @notice Processes the cross-chain payout of native tokens to a user with autonomous gas reimbursement.
     * @dev Measures execution gas in real-time, refunds the relayer, deducts gas and fee from the user,
     *      and transfers the net native tokens to the recipient.
     * @param _swapId The unique identifier of the cross-chain swap.
     * @param _user The recipient address who will receive the native tokens.
     * @param _dflAmount The amount of DFL tokens burned on the source chain (in wei).
     */
    function payoutNativeToken(
        bytes32 _swapId,
        address payable _user,
        uint256 _dflAmount
    ) external whenNotPaused onlyRelayer nonReentrant {
        uint256 startGas = gasleft();

        LibAppStorage.AppStorage storage s = LibAppStorage.layout();
        uint64 chainId = uint64(block.chainid);

        // 1. Validate swap status
        if (s.swapStates[_swapId].status != LibAppStorage.SwapStatus.None) {
            revert SwapInbound__AlreadyProcessed();
        }

        // 2. Fetch pool configuration
        LibAppStorage.PoolConfig memory config = s.poolConfigs[chainId];
        uint256 baseDiff = config.baseDifficulty;
        if (baseDiff == 0) revert SwapInbound__PoolNotConfigured();

        // 3. Compute active pool balance (excluding the accumulated feePool)
        uint256 contractBal = address(this).balance;
        uint256 feePoolBal = s.feePool;
        uint256 currentBal = contractBal > feePoolBal ? contractBal - feePoolBal : 0;

        // 4. Calculate dynamic difficulty with dynamic withdrawal penalty (swapFee)
        uint256 targetBal = config.targetBalance;
        uint256 effectiveDiff = LibPoolMath.calculateEffectiveDifficulty(
            baseDiff,
            targetBal,
            currentBal
        );

        if (s.swapFee > 0) {
            effectiveDiff = LibPoolMath.applyWithdrawPenalty(effectiveDiff, s.swapFee);
        }

        // 5. Calculate gross payout amount in native tokens (wei)
        uint256 grossPayout = (_dflAmount * 100) / effectiveDiff;
        if (currentBal < grossPayout) revert SwapInbound__InsufficientLiquidity();

        // 6. Update state to finalized before making external transfers (CEI Pattern)
        s.swapStates[_swapId].status = LibAppStorage.SwapStatus.Processed;

        // 7. Calculate actual gas spent and refund amount (including base TX fee + transfer overhead)
        uint256 gasSpent = startGas - gasleft() + s.gasOverhead;
        uint256 gasCost = gasSpent * tx.gasprice;

        if (gasCost >= grossPayout) revert SwapInbound__GasExceedsPayout();
        uint256 netPayout = grossPayout - gasCost;

        emit SwapPaidOut(_swapId, _user, grossPayout, gasCost);

        // 8. Execute transfers (Relayer gas refund & User net native token payout)
        (bool successRelayer, ) = payable(msg.sender).call{value: gasCost}("");
        if (!successRelayer) {
            revert SwapInbound__RelayerRefundFailed();
        }

        (bool successUser, ) = _user.call{value: netPayout}("");
        if (!successUser) {
            revert SwapInbound__UserPayoutFailed();
        }
    }

    /**
     * @notice Cancels a pending swap on the destination chain to permanently lock it.
     * @dev Measures gas spent, refunds the relayer from the feePool, and blocks any future payouts for this swap.
     * @param _swapId The unique identifier of the cross-chain swap.
     */
    function cancelSwap(bytes32 _swapId) external whenNotPaused onlyRelayer nonReentrant {
        uint256 startGas = gasleft();

        LibAppStorage.AppStorage storage s = LibAppStorage.layout();

        // 1. Ensure the swap has not been processed or cancelled already
        if (s.swapStates[_swapId].status != LibAppStorage.SwapStatus.None) {
            revert SwapInbound__AlreadyProcessed();
        }

        // 2. Lock the swap status to Cancelled permanently
        s.swapStates[_swapId].status = LibAppStorage.SwapStatus.Cancelled;

        // 3. Compute actual gas spent and execute relayer refund from feePool
        uint256 gasSpent = startGas - gasleft() + s.gasOverhead;
        uint256 gasCost = gasSpent * tx.gasprice;

        if (gasCost > s.feePool) revert SwapInbound__InsufficientFeePool();

        s.feePool -= gasCost;

        emit SwapCancelled(_swapId, gasCost);

        (bool successRelayer, ) = payable(msg.sender).call{value: gasCost}("");
        if (!successRelayer) {
            revert SwapInbound__RelayerRefundFailed();
        }
    }

    /**
     * @notice External view function to query expected native token payout and current difficulty.
     * @param _dflAmount The amount of DFL tokens burned on the source chain (in wei).
     * @return gasAmount The expected gross native token payout (in wei).
     * @return effectiveDiff The current dynamic difficulty multiplier.
     */
    function getNativeTokenValue(uint256 _dflAmount) external view returns (uint256 gasAmount, uint256 effectiveDiff) {
        LibAppStorage.AppStorage storage s = LibAppStorage.layout();
        uint64 chainId = uint64(block.chainid);

        LibAppStorage.PoolConfig memory config = s.poolConfigs[chainId];
        uint256 baseDiff = config.baseDifficulty;
        if (baseDiff == 0) return (0, 0);

        uint256 targetBal = config.targetBalance;

        uint256 contractBal = address(this).balance;
        uint256 feePoolBal = s.feePool;
        uint256 currentBal = contractBal > feePoolBal ? contractBal - feePoolBal : 0;

        effectiveDiff = baseDiff;
        if (currentBal < targetBal && targetBal > 0) {
            uint256 deficit = targetBal - currentBal;
            uint256 deficitRatio = (deficit * 1e18) / targetBal;
            effectiveDiff = baseDiff + (baseDiff * deficitRatio) / 1e18;
        }

        if (s.swapFee > 0) {
            effectiveDiff = effectiveDiff + (effectiveDiff * s.swapFee) / 10000;
        }

        gasAmount = (_dflAmount * 100) / effectiveDiff;
    }
}