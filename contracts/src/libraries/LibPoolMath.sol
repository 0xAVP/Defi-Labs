// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title LibPoolMath
 * @author 0xAvp
 * @notice Library for calculating dynamic pool difficulty, fee allocations, and withdrawal penalties.
 * @dev All functions are internal to ensure they are inlined into the facet bytecode, incurring zero gas overhead.
 */
library LibPoolMath {

    /**
     * @notice Calculates the dynamic difficulty multiplier based on the pool's liquidity deficit.
     * @param _baseDifficulty The baseline difficulty multiplier configured for the pool.
     * @param _targetBalance The target native asset reserve balance configured for the pool (in wei).
     * @param _currentBalance The current active native asset reserve balance of the pool (in wei).
     * @return effectiveDiff The calculated dynamic difficulty multiplier.
     */
    function calculateEffectiveDifficulty(
        uint256 _baseDifficulty,
        uint256 _targetBalance,
        uint256 _currentBalance
    ) internal pure returns (uint256 effectiveDiff) {
        effectiveDiff = _baseDifficulty;
        if (_currentBalance < _targetBalance && _targetBalance > 0) {
            uint256 deficit = _targetBalance - _currentBalance;
            uint256 deficitRatio = (deficit * 1e18) / _targetBalance;
            effectiveDiff = _baseDifficulty + (_baseDifficulty * deficitRatio) / 1e18;
        }
    }

    /**
     * @notice Calculates the protocol fee for a given gross swap amount.
     * @param _amount The gross native token swap amount (in wei).
     * @param _feeBps The fee rate configured in basis points (e.g., 50 = 0.50%).
     * @return The calculated fee amount (in wei).
     */
    function calculateFee(uint256 _amount, uint256 _feeBps) internal pure returns (uint256) {
        return (_amount * _feeBps) / 10000;
    }

    /**
     * @notice Applies the withdrawal spread penalty to the calculated difficulty.
     * @param _difficulty The difficulty multiplier before the penalty.
     * @param _feeBps The penalty rate configured in basis points.
     * @return The adjusted difficulty multiplier including the withdrawal spread.
     */
    function applyWithdrawPenalty(uint256 _difficulty, uint256 _feeBps) internal pure returns (uint256) {
        return _difficulty + (_difficulty * _feeBps) / 10000;
    }
}