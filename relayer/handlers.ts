import { encodePacked, keccak256, Hex } from "npm:viem";
import { DIAMOND_ADDRESS, SwapInboundFacetAbi, SwapToNativeInitiatedEvent } from "./config.ts";
import { account, getClients } from "./clients.ts";

/**
 * Verifies the burn transaction on the source chain and triggers the payout on the destination chain.
 */
export async function handlePayout(sourceChainId: number, destChainId: number, txHash: string) {
    const source = getClients(sourceChainId);
    const dest = getClients(destChainId);

    // 1. Fetch the transaction receipt on the Source Chain
    const receipt = await source.publicClient.getTransactionReceipt({ hash: txHash as Hex });

    // Parse logs to locate the SwapToNativeInitiated event
    const logs = await source.publicClient.parseEventLogs({
        abi: [SwapToNativeInitiatedEvent],
        logs: receipt.logs
    });

    const swapEvent = logs.find(log => log.eventName === "SwapToNativeInitiated");
    if (!swapEvent) {
        throw new Error("SwapToNativeInitiated event not found in receipt");
    }

    const { swapId, user, amount } = swapEvent.args;

    // 2. Fetch the current state of this swapId on the Destination Chain
    const [status] = await dest.publicClient.readContract({
        address: DIAMOND_ADDRESS[destChainId],
        abi: SwapInboundFacetAbi,
        functionName: "swapStates",
        args: [swapId]
    });

    if (status !== 0) {
        throw new Error("Swap already processed or cancelled on destination");
    }

    // 3. Execute the payout. The contract will automatically reimburse our gas inside this tx.
    const payoutHash = await dest.walletClient.writeContract({
        address: DIAMOND_ADDRESS[destChainId],
        abi: SwapInboundFacetAbi,
        functionName: "payoutNativeToken",
        args: [swapId, user, amount]
    });

    return { payoutHash };
}

/**
 * Verifies the swap, cancels it on the destination chain, and generates a cryptographic refund signature.
 */
export async function handleRefund(sourceChainId: number, destChainId: number, txHash: string) {
    const source = getClients(sourceChainId);
    const dest = getClients(destChainId);

    const receipt = await source.publicClient.getTransactionReceipt({ hash: txHash as Hex });

    const logs = await source.publicClient.parseEventLogs({
        abi: [SwapToNativeInitiatedEvent],
        logs: receipt.logs
    });

    const swapEvent = logs.find(log => log.eventName === "SwapToNativeInitiated");
    if (!swapEvent) {
        throw new Error("SwapToNativeInitiated event not found in receipt");
    }

    const { swapId, amount, nonce } = swapEvent.args;

    const [status] = await dest.publicClient.readContract({
        address: DIAMOND_ADDRESS[destChainId],
        abi: SwapInboundFacetAbi,
        functionName: "swapStates",
        args: [swapId]
    });

    if (status === 1) {
        throw new Error("Cannot cancel, swap already processed on destination");
    }

    let cancelHash: Hex | null = null;

    // Only call cancelSwap if it hasn't been cancelled on-chain yet
    if (status === 0) {
        cancelHash = await dest.walletClient.writeContract({
            address: DIAMOND_ADDRESS[destChainId],
            abi: SwapInboundFacetAbi,
            functionName: "cancelSwap",
            args: [swapId]
        });

        // Wait for cancellation receipt to prevent front-running refunds
        await dest.publicClient.waitForTransactionReceipt({ hash: cancelHash });
    }

    // 4. Generate the EIP-191 refund authorization signature (identical to SwapOutboundFacet.sol)
    const messageHash = keccak256(
        encodePacked(
            ["bytes32", "uint256", "uint64", "uint256", "string", "uint256"],
            [swapId, amount, BigInt(destChainId), nonce, "REFUND", BigInt(sourceChainId)]
        )
    );

    const signature = await account.signMessage({
        message: { raw: messageHash }
    });

    return { cancelHash, signature };
}