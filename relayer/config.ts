import { parseAbiItem, Hex } from "npm:viem";

// Safely fetch and validate the private key from the environment
export const PRIVATE_KEY = Deno.env.get("RELAYER_PRIVATE_KEY") as Hex;
if (!PRIVATE_KEY) {
    throw new Error("RELAYER_PRIVATE_KEY environment variable is missing!");
}

// Redundant public RPC endpoints for failover (no dependency on paid SaaS RPCs)
export const RPC_FALLBACKS: Record<number, string[]> = {
    84532: [ // Base Sepolia
        "https://sepolia.base.org",
        "https://base-sepolia-rpc.publicnode.com",
        "https://base-sepolia.blockpi.network/v1/rpc/public"
    ],
    11155111: [ // Ethereum Sepolia
        "https://eth-sepolia.public.blastapi.io",
        "https://sepolia.gateway.tenderly.co",
        "https://ethereum-sepolia-rpc.publicnode.com"
    ]
};

// Deployment addresses of the Diamond Proxy gateway on each supported chain
export const DIAMOND_ADDRESS: Record<number, Hex> = {
    84532: "0x610178dA211FEF7D417bC0e6FeD39F05609AD788",
    11155111: "0x610178dA211FEF7D417bC0e6FeD39F05609AD788"
};

// ABI item representing the initiating burn event on the Source Chain
export const SwapToNativeInitiatedEvent = parseAbiItem(
    "event SwapToNativeInitiated(bytes32 indexed swapId, address indexed user, uint256 amount, uint64 indexed destChainId, uint256 nonce)"
);

// Minimal ABI required for executing and reading SwapInboundFacet functions
export const SwapInboundFacetAbi = [
    {
        type: "function",
        name: "payoutNativeToken",
        inputs: [
            { name: "_swapId", type: "bytes32" },
            { name: "_user", type: "address" },
            { name: "_dflAmount", type: "uint256" }
        ],
        outputs: [],
        stateMutability: "nonpayable"
    },
    {
        type: "function",
        name: "cancelSwap",
        inputs: [{ name: "_swapId", type: "bytes32" }],
        outputs: [],
        stateMutability: "nonpayable"
    },
    {
        type: "function",
        name: "swapStates",
        inputs: [{ name: "", type: "bytes32" }],
        outputs: [
            { name: "status", type: "uint8" }, // 0: None, 1: Processed, 2: Cancelled
            { name: "refunded", type: "bool" }
        ],
        stateMutability: "view"
    }
] as const;