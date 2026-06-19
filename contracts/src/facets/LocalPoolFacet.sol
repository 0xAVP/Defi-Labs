// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./BaseFacet.sol";
import "../libraries/LibAppStorage.sol";
import "../libraries/LibPoolMath.sol";
import "../interfaces/IDFLToken.sol";

    error LocalPool__ZeroDeposit();
    error LocalPool__PoolNotConfigured();

/**
 * @title Local Pool Facet
 * @author 0xAvp
 * @notice Handles local swaps (Native Token -> DFL) and dynamic pool pricing.
 * @dev Inherits from BaseFacet. Integrates scarcity-based difficulty math.
 */
contract LocalPoolFacet is BaseFacet {

    event LocalDeposit(address indexed user, uint256 nativeAmount, uint256 dflAmount, uint256 effectiveDifficulty);

    /**
     * @notice Deposits native tokens to mint DFL utility tokens.
     * @dev Deducts a protocol fee into feePool, calculates dynamic difficulty based on liquidity deficit,
     *      and mints proportional DFL tokens to the depositor.
     */
    function depositNativeToken() external payable whenNotPaused nonReentrant {
        uint256 depositAmount = msg.value;
        if (depositAmount == 0) revert LocalPool__ZeroDeposit();

        LibAppStorage.AppStorage storage s = LibAppStorage.layout();
        uint64 chainId = uint64(block.chainid);

        LibAppStorage.PoolConfig memory config = s.poolConfigs[chainId];
        uint256 baseDiff = config.baseDifficulty;
        if (baseDiff == 0) revert LocalPool__PoolNotConfigured();

        // 1. Calculate and allocate protocol fees
        uint256 fee = LibPoolMath.calculateFee(depositAmount, s.swapFee);
        s.feePool += fee;
        uint256 netDeposit = depositAmount - fee;

        // 2. Calculate current active pool liquidity prior to this deposit
        uint256 contractBal = address(this).balance;
        uint256 feePoolBal = s.feePool;
        uint256 currentBal = 0;

        // Prevent underflow if non-pool funds are ever transferred or during extreme edge cases
        if (contractBal > feePoolBal + depositAmount) {
            currentBal = contractBal - feePoolBal - depositAmount;
        }

        // 3. Compute dynamic difficulty based on current pool deficit using library
        uint256 targetBal = config.targetBalance;
        uint256 effectiveDiff = LibPoolMath.calculateEffectiveDifficulty(
            baseDiff,
            targetBal,
            currentBal
        );

        // 4. Calculate DFL output and mint to user
        uint256 dflAmount = (netDeposit * effectiveDiff) / 100;

        emit LocalDeposit(msg.sender, depositAmount, dflAmount, effectiveDiff);

        IDFLToken(s.dflToken).mint(msg.sender, dflAmount);
    }

    /**
     * @notice External view function to query expected DFL payout and current deposit difficulty.
     * @param _amount The gross amount of native tokens (in wei) proposed for deposit.
     * @return dflAmount The expected net amount of DFL tokens to be minted (in wei).
     * @return effectiveDiff The current dynamic difficulty multiplier used for calculation.
     */
    function getDflValue(uint256 _amount) external view returns (uint256 dflAmount, uint256 effectiveDiff) {
        LibAppStorage.AppStorage storage s = LibAppStorage.layout();
        uint64 chainId = uint64(block.chainid);

        LibAppStorage.PoolConfig memory config = s.poolConfigs[chainId];
        uint256 baseDiff = config.baseDifficulty;
        if (baseDiff == 0) return (0, 0);

        uint256 targetBal = config.targetBalance;

        // Compute active liquidity pool balance (excluding accumulated protocol fees)
        uint256 contractBal = address(this).balance;
        uint256 feePoolBal = s.feePool;
        uint256 currentBal = contractBal > feePoolBal ? contractBal - feePoolBal : 0;

        // Compute dynamic difficulty using library
        effectiveDiff = LibPoolMath.calculateEffectiveDifficulty(
            baseDiff,
            targetBal,
            currentBal
        );

        // Apply protocol fee deduction using library and compute net DFL output
        uint256 fee = LibPoolMath.calculateFee(_amount, s.swapFee);
        uint256 netAmount = _amount - fee;

        dflAmount = (netAmount * effectiveDiff) / 100;
    }
}