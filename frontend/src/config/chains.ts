// frontend/src/constants/chains.ts

export interface DestinationChain {
    id: string;     // CCIP Chain Selector (or "0" for local chain)
    name: string;   // Human-readable chain name
    symbol: string; // Native gas token symbol
}

/**
 * @notice Configuration array for all supported gas bridge destination chains.
 * @dev Add new CCIP destination chains here to automatically render them in the UI.
 */
export const DESTINATION_CHAINS: DestinationChain[] = [
    { id: "0", name: "Base Sepolia (Local)", symbol: "ETH" },
    { id: "16015286601757825753", name: "Ethereum Sepolia (CCIP)", symbol: "ETH" },
    { id: "16281711391670634445", name: "Polygon Amoy (CCIP)", symbol: "MATIC" }
];