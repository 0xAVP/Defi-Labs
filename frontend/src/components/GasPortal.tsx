import { useState, useEffect } from "react";
import { useAccount, useBalance, useWaitForTransactionReceipt } from "wagmi";
import { formatEther, parseEther } from "viem";
import { DIAMOND_ADDRESS, DFL_TOKEN_ADDRESS } from "../config/addresses";
import { DESTINATION_CHAINS } from "../config/chains";

import {
    useReadDflTokenAllowance,
    useWriteDflToken,
    useReadLiquidityPortalFacetGetDflValue,
    useReadLiquidityPortalFacetGetGasValue,
    useWriteLiquidityPortalFacet,
} from "../generated";

interface GasPortalProps {
    refetchBalance: () => void;
}

export default function GasPortal({ refetchBalance }: GasPortalProps) {
    const [portalMode, setPortalMode] = useState<"mint" | "redeem">("mint");
    const [amount, setAmount] = useState<string>("1");
    const [destChain, setDestChain] = useState<string>("0");

    const { address, isConnected } = useAccount();

    // Fetch current pool balance (ETH balance of the Diamond)
    const { data: diamondBalance, refetch: refetchPoolBalance } = useBalance({
        address: DIAMOND_ADDRESS,
    });

    // Fetch DFL allowance
    const { data: dflAllowance, refetch: refetchAllowance } = useReadDflTokenAllowance({
        address: DFL_TOKEN_ADDRESS,
        args: address ? [address, DIAMOND_ADDRESS] : undefined,
        query: { enabled: !!address },
    });

    // Query expected DFL payout (Mint Mode)
    const { data: mintQuote, isFetching: isMintLoading } = useReadLiquidityPortalFacetGetDflValue({
        address: DIAMOND_ADDRESS,
        args: [parseEther(amount || "0")],
        query: { enabled: isConnected && portalMode === "mint" && Number(amount) > 0 },
    });

    // Query expected native gas payout (Redeem Mode)
    const { data: redeemQuote, isFetching: isRedeemLoading } = useReadLiquidityPortalFacetGetGasValue({
        address: DIAMOND_ADDRESS,
        args: [parseEther(amount || "0")],
        query: { enabled: isConnected && portalMode === "redeem" && Number(amount) > 0 && destChain === "0" },
    });

    // 2. Setup write hooks and capture transaction hashes
    const { writeContract: writePortal, data: portalHash } = useWriteLiquidityPortalFacet();
    const { writeContract: writeToken, data: tokenHash } = useWriteDflToken();

    // 3. Setup transaction waiters to wait until blocks are actually mined!
    const { isLoading: isPortalPending, isSuccess: isPortalConfirmed } = useWaitForTransactionReceipt({
        hash: portalHash,
    });

    const { isLoading: isApprovePending, isSuccess: isApproveConfirmed } = useWaitForTransactionReceipt({
        hash: tokenHash,
    });

    // 4. Refetch state only AFTER transactions are physically mined on-chain
    useEffect(() => {
        if (isPortalConfirmed || isApproveConfirmed) {
            refetchBalance();
            refetchAllowance();
            refetchPoolBalance();
        }
    }, [isPortalConfirmed, isApproveConfirmed, refetchBalance, refetchAllowance, refetchPoolBalance]);

    const handleDeposit = () => {
        if (!isConnected || !amount) return;
        writePortal({
            address: DIAMOND_ADDRESS,
            functionName: "depositGas",
            value: parseEther(amount),
        });
    };

    const handleApprove = () => {
        if (!isConnected || !amount) return;
        writeToken({
            address: DFL_TOKEN_ADDRESS,
            functionName: "approve",
            args: [DIAMOND_ADDRESS, parseEther(amount)],
        });
    };

    const handleRedeem = () => {
        if (!isConnected || !amount) return;
        writePortal({
            address: DIAMOND_ADDRESS,
            functionName: "redeemGas",
            args: [BigInt(destChain), parseEther(amount)],
        });
    };

    const hasSufficientAllowance =
        dflAllowance !== undefined && dflAllowance >= parseEther(amount || "0");

    // ====================================================================
    // SAFE UI QUOTE CALCULATIONS
    // ====================================================================
    const displayMintDfl = mintQuote ? Number(formatEther(mintQuote[0])).toFixed(4) : "0.00";
    const displayMintDiff = mintQuote ? (Number(mintQuote[1]) / 100).toFixed(2) : "1.00";

    const displayRedeemGas = redeemQuote ? Number(formatEther(redeemQuote[0])).toFixed(6) : "0.000000";
    const displayRedeemDiff = redeemQuote ? (Number(redeemQuote[1]) / 100).toFixed(2) : "1.05";

    // Calculate pool metrics
    const displayPoolBalance = diamondBalance ? Number(diamondBalance.formatted).toFixed(4) : "0.0000";

    // 5. Check if the local pool has enough native gas (ETH) to fulfill the withdrawal
    const isLiquidityInsufficient =
        portalMode === "redeem" &&
        destChain === "0" &&
        redeemQuote !== undefined &&
        diamondBalance !== undefined &&
        redeemQuote[0] > diamondBalance.value;

    return (
        <div className="card bg-base-200 shadow-xl p-6">
            <h2 className="card-title mb-2">Gas Liquidity Portal</h2>
            <p className="text-sm text-base-content/70 mb-6">
                Provide native gas to earn DFL utility tokens, or burn your DFL to withdraw native gas back to your wallet.
            </p>

            {isConnected ? (
                <div className="flex flex-col gap-6 max-w-md">
                    {/* Mode Selector */}
                    <div className="tabs tabs-boxed bg-base-100 p-1 rounded-xl">
                        <button
                            onClick={() => { setPortalMode("mint"); setAmount("0.01"); }}
                            className={`tab flex-1 rounded-lg ${portalMode === "mint" ? "tab-active bg-primary text-primary-content" : ""}`}
                        >
                            Mint DFL
                        </button>
                        <button
                            onClick={() => { setPortalMode("redeem"); setAmount("1"); }}
                            className={`tab flex-1 rounded-lg ${portalMode === "redeem" ? "tab-active bg-primary text-primary-content" : ""}`}
                        >
                            Redeem Gas
                        </button>
                    </div>

                    {/* Network Selector */}
                    {portalMode === "redeem" && (
                        <div className="form-control w-full">
                            <label className="label">
                                <span className="label-text">Select Destination Network:</span>
                            </label>
                            <select
                                value={destChain}
                                onChange={(e) => setDestChain(e.target.value)}
                                className="select select-bordered w-full rounded-xl font-medium"
                            >
                                {DESTINATION_CHAINS.map((chain) => (
                                    <option key={chain.id} value={chain.id}>
                                        {chain.name}
                                    </option>
                                ))}
                            </select>
                        </div>
                    )}

                    {/* Amount Form */}
                    <div className="form-control w-full">
                        <label className="label">
              <span className="label-text">
                {portalMode === "mint" ? "Amount of ETH to deposit:" : "Amount of DFL to burn:"}
              </span>
                        </label>
                        <div className="join">
                            <input
                                type="number"
                                placeholder="0"
                                value={amount}
                                onChange={(e) => setAmount(e.target.value)}
                                className="input input-bordered join-item w-full rounded-xl"
                                min="0"
                            />
                            <button className="btn btn-active join-item rounded-r-xl">
                                {portalMode === "mint" ? "ETH" : "DFL"}
                            </button>
                        </div>
                    </div>

                    {/* STATS CARD */}
                    {destChain === "0" || portalMode === "mint" ? (
                        <div className="bg-base-100 p-4 rounded-xl border border-base-100 text-sm space-y-2.5 font-medium relative">
                            <div className="flex justify-between items-center">
                <span className="text-base-content/50">
                  {portalMode === "mint" ? "Current Multiplier:" : "Withdraw Difficulty:"}
                </span>
                                <span className="text-primary font-bold">
                  {isMintLoading || isRedeemLoading ? (
                      <span className="loading loading-double-spinner loading-xs"></span>
                  ) : (
                      `${portalMode === "mint" ? displayMintDiff : displayRedeemDiff}x`
                  )}
                </span>
                            </div>
                            <div className="flex justify-between items-center">
                                <span className="text-base-content/50">You will receive:</span>
                                <span className="text-secondary font-bold">
                  {isMintLoading || isRedeemLoading ? (
                      <span className="loading loading-double-spinner loading-xs"></span>
                  ) : (
                      `${portalMode === "mint" ? displayMintDfl : displayRedeemGas} ${portalMode === "mint" ? "DFL" : "ETH"}`
                  )}
                </span>
                            </div>

                            {/* POOL RESERVES ROW */}
                            <div className="flex justify-between items-center border-t border-base-200/50 pt-2.5 mt-2.5">
                                <span className="text-base-content/50">Pool Reserves:</span>
                                <span className="text-base-content font-bold font-mono">
                  {displayPoolBalance} ETH
                </span>
                            </div>
                        </div>
                    ) : (
                        /* Cross-Chain Inactive Warning */
                        <div className="bg-base-100 p-4 rounded-xl border border-base-100 text-sm space-y-3 font-medium">
                            <div className="flex justify-between items-center">
                                <span className="text-base-content/50">Status:</span>
                                <span className="badge badge-sm badge-warning p-3">Inactive</span>
                            </div>
                            <p className="text-xs text-base-content/50 leading-relaxed">
                                Note: Cross-chain bridging to this network is currently inactive on-chain. The bridge contract facets (Phase 2 CCIP) are not registered yet. Only local redemption on Base Sepolia is active.
                            </p>
                        </div>
                    )}

                    {/* Action Buttons */}
                    {portalMode === "mint" ? (
                        <button
                            onClick={handleDeposit}
                            disabled={isPortalPending || !amount}
                            className="btn btn-primary rounded-xl w-full"
                        >
                            {isPortalPending ? <span className="loading loading-spinner"></span> : "Deposit Gas & Mint DFL"}
                        </button>
                    ) : (
                        <div className="w-full">
                            {destChain !== "0" ? (
                                <button disabled className="btn btn-disabled rounded-xl w-full">
                                    Bridge Inactive
                                </button>
                            ) : isLiquidityInsufficient ? (
                                /* 6. Блокируем кнопку, если в пуле недостаточно ликвидности для этого вывода */
                                <button disabled className="btn btn-disabled rounded-xl w-full text-error border-error/20 bg-error/5">
                                    Insufficient Pool Liquidity
                                </button>
                            ) : hasSufficientAllowance ? (
                                <button
                                    onClick={handleRedeem}
                                    disabled={isPortalPending || !amount}
                                    className="btn btn-primary rounded-xl w-full"
                                >
                                    {isPortalPending ? <span className="loading loading-spinner"></span> : "Burn DFL & Redeem Gas"}
                                </button>
                            ) : (
                                <button
                                    onClick={handleApprove}
                                    disabled={isApprovePending || !amount}
                                    className="btn btn-secondary rounded-xl w-full"
                                >
                                    {isApprovePending ? <span className="loading loading-spinner"></span> : "Approve DFL Spending"}
                                </button>
                            )}
                        </div>
                    )}
                </div>
            ) : (
                <div className="alert alert-warning rounded-xl">
                    <span>Please connect your wallet to interact with the Gas Portal.</span>
                </div>
            )}
        </div>
    );
}