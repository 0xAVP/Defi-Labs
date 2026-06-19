import { handlePayout, handleRefund } from "./handlers.ts";

// Standard CORS headers allowing any origin (necessary for React frontends)
const headers = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Content-Type": "application/json"
};

Deno.serve(async (req: Request) => {
    const url = new URL(req.url);
    const path = url.pathname;

    // Handle preflight requests
    if (req.method === "OPTIONS") {
        return new Response(null, { status: 204, headers });
    }

    try {
        if (req.method !== "POST") {
            return new Response(JSON.stringify({ error: "Only POST method is allowed" }), { status: 405, headers });
        }

        const { sourceChainId, destChainId, txHash } = await req.json();
        if (!sourceChainId || !destChainId || !txHash) {
            return new Response(JSON.stringify({ error: "Missing required fields" }), { status: 400, headers });
        }

        // Route: Process Payout
        if (path === "/payout") {
            const { payoutHash } = await handlePayout(Number(sourceChainId), Number(destChainId), txHash);
            return new Response(JSON.stringify({
                success: true,
                message: "Payout successful!",
                txHash: payoutHash
            }), { status: 200, headers });
        }

        // Route: Process Cancel & Sign Refund
        if (path === "/refund") {
            const { cancelHash, signature } = await handleRefund(Number(sourceChainId), Number(destChainId), txHash);
            return new Response(JSON.stringify({
                success: true,
                message: "Swap cancelled and signature generated successfully!",
                cancelTxHash: cancelHash,
                signature: signature
            }), { status: 200, headers });
        }

        return new Response(JSON.stringify({ error: "Endpoint not found" }), { status: 404, headers });

    } catch (error) {
        console.error("Error executing handler:", error);
        return new Response(JSON.stringify({ error: (error as Error).message }), { status: 500, headers });
    }
});