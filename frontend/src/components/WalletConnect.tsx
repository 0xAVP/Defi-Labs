// frontend/src/components/WalletConnect.tsx
import { useAccount, useConnect, useDisconnect, useWalletClient } from "wagmi";
import { formatEther } from "viem";
import { DFL_TOKEN_ADDRESS } from "../config/addresses";

interface WalletConnectProps {
    dflBalance: bigint | undefined;
    refetchBalance: () => void;
}

export default function WalletConnect({ dflBalance, refetchBalance }: WalletConnectProps) {
    const { address, isConnected } = useAccount();
    const { connect, connectors } = useConnect();
    const { disconnect } = useDisconnect();
    const { data: walletClient } = useWalletClient();

    // EIP-747: Request wallet to track DFL token
    const addTokenToWallet = async () => {
        if (!walletClient) return;
        try {
            await walletClient.watchAsset({
                type: "ERC20",
                options: {
                    address: DFL_TOKEN_ADDRESS,
                    symbol: "DFL",
                    decimals: 18,
                },
            });
            refetchBalance();
        } catch (e) {
            console.error(e);
        }
    };

    if (!isConnected) {
        return (
            <div className="dropdown dropdown-end">
                <div tabIndex={0} role="button" className="btn btn-primary btn-sm rounded-xl">
                    Connect Wallet
                </div>
                <ul tabIndex={0} className="dropdown-content menu bg-base-200 rounded-box z-[1] w-52 p-2 shadow-2xl mt-2 border border-base-100">
                    {connectors.map((connector) => (
                        <li key={connector.uid}>
                            <button onClick={() => connect({ connector })} className="py-2.5 font-medium rounded-lg">
                                {connector.name}
                            </button>
                        </li>
                    ))}
                </ul>
            </div>
        );
    }

    return (
        <div className="flex items-center gap-4">
            {dflBalance !== undefined && (
                <div className="flex items-center gap-2">
                    <div className="badge badge-outline badge-secondary p-4 gap-2 font-mono">
                        Balance: {Number(formatEther(dflBalance)).toFixed(2)} DFL
                    </div>
                    <button
                        onClick={addTokenToWallet}
                        className="btn btn-xs btn-outline btn-secondary rounded-xl normal-case"
                        title="Add DFL to Wallet"
                    >
                        🦊 Add to Wallet
                    </button>
                </div>
            )}

            <div className="flex items-center gap-3">
        <span className="font-mono text-sm bg-base-100 px-3 py-2 rounded-xl border border-base-100">
          {address?.slice(0, 6)}...{address?.slice(-4)}
        </span>
                <button onClick={() => disconnect()} className="btn btn-error btn-outline btn-sm rounded-xl">
                    Disconnect
                </button>
            </div>
        </div>
    );
}