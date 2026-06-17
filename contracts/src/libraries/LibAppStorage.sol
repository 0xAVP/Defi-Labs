// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DeFi Labs App Storage Library
 * @author 0xAvp
 * @notice Shared storage layout for the EIP-2535 Diamond proxy.
 * @dev All facets must import this library and access state via LibAppStorage.layout()
 *      to ensure synchronized storage slots and prevent collisions.
 */
library LibAppStorage {
    // Unique storage slot position for AppStorage (EIP-7201 standard)
    bytes32 internal constant APP_STORAGE_POSITION = keccak256("defi.labs.storage.appstorage");

    /**
     * @notice Struct representing a single cross-chain gas stream/swap
     * @dev Variable packing: uint64 (8 bytes) + uint64 (8 bytes) + address (20 bytes) = 36 bytes.
     *      Solidity will pack this into two 32-byte slots.
     */
    struct GasSwap {
        address swapper;        // Address of the user who initiated the swap
        uint64 sourceChainId;   // CCIP source chain selector
        uint64 timestamp;       // Block timestamp of the swap
        uint256 amountIn;       // Amount of native gas sent on the source chain
        uint256 amountOut;      // Expected amount of native gas to receive on destination
    }

    /**
     * @notice Struct representing a time-locked governance token stake
     */
    struct LockedBalance {
        uint128 amount;         // Amount of DFL tokens locked
        uint128 unlockTime;     // Timestamp when tokens can be unlocked
    }

    /**
     * @notice Main storage structure containing the state of all DeFi modules
     * @dev Explicit slot layout is documented below for future upgrade safety.
     *      Each slot is exactly 32 bytes.
     */
    struct AppStorage {
        // ====================================================================
        // SLOT 0 (Occupied: 22 bytes, Free: 10 bytes)
        // ====================================================================
        // [0..20] owner of the Diamond proxy
        address owner;
        // [20..21] global emergency pause flag
        bool paused;
        // [21..22] standard reentrancy guard status (1 = Active, 2 = Guarded)
        uint8 reentrancyStatus;
        // [22..32] UNUSED (10 bytes remaining for future small uints/bools)

        // ====================================================================
        // SLOT 1 (Occupied: 20 bytes, Free: 12 bytes)
        // ====================================================================
        // [0..20] DeFi Labs Governance/Utility Token address
        address dflToken;
        // [20..32] UNUSED (12 bytes remaining)

        // ====================================================================
        // SLOT 2 (Occupied: 20 bytes, Free: 12 bytes)
        // ====================================================================
        // [0..20] Chainlink CCIP Router address
        address ccipRouter;
        // [20..32] UNUSED (12 bytes remaining)

        // ====================================================================
        // SLOT 3 (Occupied: 20 bytes, Free: 12 bytes)
        // ====================================================================
        // [0..20] Chainlink Price Feed Aggregator address (e.g., ETH/USD)
        address priceOracle;
        // [20..32] UNUSED (12 bytes remaining)

        // ====================================================================
        // SLOT 4 (Occupied: 32 bytes)
        // ====================================================================
        // [0..32] Base withdrawal penalty / spread multiplier
        // (e.g., 500 = 5.00% fee based on 10,000 basis points)
        uint256 withdrawFee;

        // ====================================================================
        // SLOT 5 (Occupied: 32 bytes - Mapping Root Placeholder)
        // ====================================================================
        // CCIP Destination Chain Selector => Peer Bridge contract address
        mapping(uint64 => address) peerBridges;

        // ====================================================================
        // SLOT 6 (Occupied: 32 bytes - Mapping Root Placeholder)
        // ====================================================================
        // Track completed or pending swaps to prevent double-execution
        mapping(bytes32 => bool) processedMessageIds;

        // ====================================================================
        // SLOT 7 (Occupied: 32 bytes - Mapping Root Placeholder)
        // ====================================================================
        // User address => Lock configuration (ve-Tokenomics)
        mapping(address => LockedBalance) lockedBalances;

        // ====================================================================
        // SLOT 8 (Occupied: 32 bytes - Mapping Root Placeholder)
        // ====================================================================
        // User address => EIP-712 permit nonce for gasless approvals
        mapping(address => uint256) nonces;

        // ====================================================================
        // SLOT 9 (Occupied: 32 bytes - Mapping Root Placeholder)
        // ====================================================================
        // CCIP Destination Chain Selector (or block.chainid) => Base Difficulty
        // (e.g., 100 = 1.0x baseline difficulty multiplier)
        mapping(uint64 => uint256) chainDifficulties;

        // ====================================================================
        // SLOT 10 (Occupied: 32 bytes - Mapping Root Placeholder)
        // ====================================================================
        // CCIP Destination Chain Selector (or block.chainid) => Target Balance (in wei)
        mapping(uint64 => uint256) targetBalances;
    }

    /**
     * @notice Returns a pointer to the shared storage layout in the Diamond proxy
     * @dev Uses inline assembly to point directly to the predefined storage slot position
     * @return ds Pointer to the AppStorage struct in state
     */
    function layout() internal pure returns (AppStorage storage ds) {
        bytes32 position = APP_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
        return ds;
    }
}