// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title LibAppStorage
 * @author 0xAvp
 * @notice Shared storage layout for the EIP-2535 Diamond proxy.
 * @dev All facets must import this library and access state via LibAppStorage.layout()
 *      to ensure synchronized storage slots and prevent collisions (EIP-7201 standard).
 */
library LibAppStorage {

    /// @dev Unique storage slot position for AppStorage (EIP-7201 standard).
    ///      Computed as keccak256("defi.labs.storage.appstorage").
    bytes32 internal constant APP_STORAGE_POSITION = keccak256("defi.labs.storage.appstorage");

    /**
     * @notice Execution status of a cross-chain swap on the destination chain.
     */
    enum SwapStatus {
        None,         // 0: The swap has not been processed yet.
        Processed,    // 1: Payout successful, native gas tokens sent to the user.
        Cancelled     // 2: Cancelled by the relayer, blocking future payouts forever.
    }

    /**
     * @notice Represents the packed state of a single cross-chain swap.
     * @dev Variable packing: SwapStatus (1 byte) + bool (1 byte) = 2 bytes.
     *      Solidity will pack this struct into a single 32-byte slot within the mapping,
     *      highly optimizing gas costs for storage reads and writes.
     */
    struct SwapState {
        SwapStatus status;       // Execution status on the destination chain (None/Processed/Cancelled).
        bool refunded;           // Flag indicating whether the DFL tokens were refunded on the source chain.
    }

    /**
     * @notice Represents the configuration parameters of a specific liquidity pool linked to a destination network.
     */
    struct PoolConfig {
        address peerBridge;      // Peer bridge contract (Diamond proxy) address on the target network.
        uint256 baseDifficulty;  // Base difficulty multiplier for the pool (e.g., 100 = 1.0x).
        uint256 targetBalance;   // Desired native asset reserve balance for the pool (in wei).
    }

    /**
     * @notice Main storage structure containing the state of all DeFi modules.
     * @dev Explicit slot layout is documented below for future upgrade safety.
     *      Each storage slot is exactly 32 bytes wide.
     */
    struct AppStorage {
        // ====================================================================
        // SLOT 0 (Occupied: 22 bytes, Free: 10 bytes)
        // ====================================================================
        /// @dev Address of the Diamond proxy owner/administrator.
        address owner;
        /// @dev Global emergency pause flag. If true, all user-facing swap operations are paused.
        bool paused;
        /// @dev Reentrancy guard status (1 = Active/Unlocked, 2 = Guarded/Locked).
        uint8 reentrancyStatus;

        // ====================================================================
        // SLOT 1 (Occupied: 20 bytes, Free: 12 bytes)
        // ====================================================================
        /// @dev Address of the core DFL utility/governance ERC20 token contract.
        address dflToken;

        // ====================================================================
        // SLOT 2 (Occupied: 24 bytes, Free: 8 bytes)
        // ====================================================================
        // [0..20] Authorized Relayer/Worker hot wallet address
        address relayer;
        // [20..24] Customizable gas overhead to account for execution steps outside gasleft()
        uint32 gasOverhead;

        // ====================================================================
        // SLOT 3 (Occupied: 32 bytes)
        // ====================================================================
        /// @dev Base swap fee multiplier in basis points (e.g., 50 = 0.50% fee based on 10,000 bps).
        uint256 swapFee;

        // ====================================================================
        // SLOT 4 (Occupied: 32 bytes)
        // ====================================================================
        /// @dev Accumulated protocol fees in native token (gas/fee pool).
        ///      Used to reimburse the relayer's gas and acts as withdrawable protocol profit.
        uint256 feePool;

        // ====================================================================
        // SLOT 5 (Occupied: 32 bytes - Mapping Root Placeholder)
        // ====================================================================
        /// @dev Maps a unique Swap ID (keccak256 hash) to its execution and refund state.
        mapping(bytes32 => SwapState) swapStates;

        // ====================================================================
        // SLOT 6 (Occupied: 32 bytes - Mapping Root Placeholder)
        // ====================================================================
        /// @dev Maps a user's address to their EIP-712 permit nonce (used for gasless DFL approvals).
        mapping(address => uint256) nonces;

        // ====================================================================
        // SLOT 7 (Occupied: 32 bytes - Mapping Root Placeholder)
        // ====================================================================
        /// @dev Maps a user's address to their transaction counter, ensuring mathematically unique swap IDs.
        mapping(address => uint256) swapNonces;

        // ====================================================================
        // SLOT 8 (Occupied: 32 bytes - Mapping Root Placeholder)
        // ====================================================================
        /// @dev Maps a target network Chain ID (CCIP selector or block.chainid) to its PoolConfig parameters.
        mapping(uint64 => PoolConfig) poolConfigs;
    }

    /**
     * @notice Returns a pointer to the shared storage layout in the Diamond proxy.
     * @dev Uses inline assembly to point directly to the predefined EIP-7201 storage slot.
     * @return ds Pointer to the AppStorage struct in contract storage.
     */
    function layout() internal pure returns (AppStorage storage ds) {
        bytes32 position = APP_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
        return ds;
    }
}