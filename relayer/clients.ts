import { createPublicClient, createWalletClient, fallback, http } from "npm:viem";
import { privateKeyToAccount } from "npm:viem/accounts";
import { PRIVATE_KEY, RPC_FALLBACKS } from "./config.ts";

// Instantiate the wallet account from the private key
export const account = privateKeyToAccount(PRIVATE_KEY);

/**
 * Creates and configures public and wallet clients for a specific chain with fallback transport.
 * @param chainId The EVM chain identifier.
 * @returns Configured public and wallet clients.
 */
export function getClients(chainId: number) {
    const rpcs = RPC_FALLBACKS[chainId];
    if (!rpcs) throw new Error(`Unsupported Chain ID: ${chainId}`);

    // Create an automated, resilient fallback transport across multiple public nodes
    const transport = fallback(rpcs.map(url => http(url)));

    const publicClient = createPublicClient({ transport });
    const walletClient = createWalletClient({ account, transport });

    return { publicClient, walletClient };
}