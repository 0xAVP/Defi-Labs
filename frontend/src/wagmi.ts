import { createConfig, http } from 'wagmi';
import { baseSepolia, sepolia, hardhat } from 'wagmi/chains';
import { injected } from 'wagmi/connectors';

export const config = createConfig({
    chains: [hardhat, baseSepolia, sepolia],
    connectors: [
        injected(),
    ],
    transports: {
        [hardhat.id]: http('http://127.0.0.1:8545'),
        [baseSepolia.id]: http(),
        [sepolia.id]: http(),
    },
});