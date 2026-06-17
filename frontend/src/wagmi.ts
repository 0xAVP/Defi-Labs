import { createConfig, http } from 'wagmi';
import { baseSepolia, sepolia } from 'wagmi/chains';
import { injected } from 'wagmi/connectors';

export const config = createConfig({
    chains: [baseSepolia, sepolia],
    connectors: [
        injected(),
    ],
    transports: {
        [baseSepolia.id]: http(),
        [sepolia.id]: http(),
    },
});