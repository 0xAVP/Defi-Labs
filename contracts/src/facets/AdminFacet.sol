// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./BaseFacet.sol";
import "../libraries/LibAppStorage.sol";

    error Admin__InvalidDifficulty();
    error Admin__InsufficientFeeBalance();

/**
 * @title System Administration Facet
 * @author 0xAvp
 * @notice Centralized facet handling all governance, configurations, and pool parameters.
 * @dev Inherits from BaseFacet. All state-modifying functions must be restricted via onlyOwner.
 */
contract AdminFacet is BaseFacet {

    event PoolConfigUpdated(uint64 indexed chainId, address peerBridge, uint256 baseDifficulty, uint256 targetBalance);
    event SwapFeeUpdated(uint256 oldFee, uint256 newFee);
    event RelayerUpdated(address oldRelayer, address newRelayer);
    event DflTokenUpdated(address oldToken, address newToken);
    event PauseStateChanged(bool isPaused);
    event FeesWithdrawn(address indexed recipient, uint256 amount);
    event GasOverheadUpdated(uint32 oldOverhead, uint32 newOverhead);

    /**
     * @notice Configures liquidity pool parameters for a specific destination network.
     * @param _chainId The target EVM chain identifier (or destination chain selector).
     * @param _peerBridge The address of the peer bridge contract on the destination chain.
     * @param _baseDifficulty Base difficulty multiplier for the pool (e.g. 100 = 1.0x).
     * @param _targetBalance Desired native token reserves in the pool (in wei).
     */
    function setPoolConfig(
        uint64 _chainId,
        address _peerBridge,
        uint256 _baseDifficulty,
        uint256 _targetBalance
    ) external onlyOwner {
        if (_baseDifficulty == 0) revert Admin__InvalidDifficulty();

        LibAppStorage.AppStorage storage s = LibAppStorage.layout();

        s.poolConfigs[_chainId] = LibAppStorage.PoolConfig({
            peerBridge: _peerBridge,
            baseDifficulty: _baseDifficulty,
            targetBalance: _targetBalance
        });

        emit PoolConfigUpdated(_chainId, _peerBridge, _baseDifficulty, _targetBalance);
    }

    /**
     * @notice Configures the base protocol fee rate for swaps.
     * @param _fee Fee multiplier in basis points (e.g., 50 = 0.50% based on 10,000 basis points).
     */
    function setSwapFee(uint256 _fee) external onlyOwner {
        LibAppStorage.AppStorage storage s = LibAppStorage.layout();
        uint256 oldFee = s.swapFee;
        s.swapFee = _fee;

        emit SwapFeeUpdated(oldFee, _fee);
    }

    /**
     * @notice Configures the authorized relayer (hot wallet) address in AppStorage.
     * @param _relayer The hot wallet address of the off-chain worker.
     */
    function setRelayer(address _relayer) external onlyOwner {
        LibAppStorage.AppStorage storage s = LibAppStorage.layout();
        address oldRelayer = s.relayer;
        s.relayer = _relayer;

        emit RelayerUpdated(oldRelayer, _relayer);
    }

    /**
     * @notice Configures the core DFL token address in AppStorage.
     * @param _dflToken The address of the DFLToken contract.
     */
    function setDflToken(address _dflToken) external onlyOwner {
        LibAppStorage.AppStorage storage s = LibAppStorage.layout();
        address oldToken = s.dflToken;
        s.dflToken = _dflToken;

        emit DflTokenUpdated(oldToken, _dflToken);
    }

    /**
     * @notice Globally pauses or unpauses all user-facing bridge interactions.
     * @param _paused True to pause the system, false to resume operations.
     */
    function setPaused(bool _paused) external onlyOwner {
        LibAppStorage.AppStorage storage s = LibAppStorage.layout();
        s.paused = _paused;

        emit PauseStateChanged(_paused);
    }

    /**
     * @notice Withdraws accumulated protocol fees from the fee pool.
     * @param _recipient The address to receive the withdrawn native tokens.
     * @param _amount The amount of native tokens (in wei) to withdraw.
     */
    function withdrawFees(address payable _recipient, uint256 _amount) external onlyOwner {
        LibAppStorage.AppStorage storage s = LibAppStorage.layout();
        if (_amount > s.feePool) revert Admin__InsufficientFeeBalance();

        s.feePool -= _amount;
        _recipient.transfer(_amount);

        emit FeesWithdrawn(_recipient, _amount);
    }

    /**
     * @notice Configures the gas overhead multiplier for relayer refunds.
     * @param _overhead The gas overhead amount (e.g., 30000) to compensate for baseline transaction execution.
     */
    function setGasOverhead(uint32 _overhead) external onlyOwner {
        LibAppStorage.AppStorage storage s = LibAppStorage.layout();
        uint32 oldOverhead = s.gasOverhead;
        s.gasOverhead = _overhead;

        emit GasOverheadUpdated(oldOverhead, _overhead);
    }
}