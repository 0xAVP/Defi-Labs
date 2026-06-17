import { useState } from "react";
import { useAccount, useConnect, useDisconnect } from "wagmi";

export default function App() {
  const [activeTab, setActiveTab] = useState<string>("streaming");

  // Web3 State using native Wagmi hooks
  const { address, isConnected } = useAccount();
  const { connect, connectors } = useConnect();
  const { disconnect } = useDisconnect();

  // List of DeFi playground modules for the sidebar
  const tabs = [
    { id: "faucet", name: "🚰 Faucet" },
    { id: "streaming", name: "🌊 Money Streaming" },
    { id: "flashloan", name: "⚡ Flash Loans" },
    { id: "staking", name: "🥩 Liquid Staking" },
    { id: "options", name: "📈 Options Trading" },
    { id: "governance", name: "🔒 Governance (ve)" },
    { id: "lending", name: "🖼️ NFT Lending" },
  ];

  return (
      <div className="flex h-screen bg-base-300 text-base-content">
        {/* 1. SIDEBAR (Left) */}
        <aside className="w-80 bg-base-200 flex flex-col justify-between border-r border-base-100 p-4">
          <div>
            <div className="flex items-center gap-2 px-2 py-4">
            <span className="text-2xl font-bold bg-gradient-to-r from-primary to-secondary bg-clip-text text-transparent">
              DeFi Labs
            </span>
              <span className="badge badge-sm badge-outline badge-primary">Diamond</span>
            </div>

            <ul className="menu menu-md w-full gap-1 p-0 mt-4">
              {tabs.map((tab) => (
                  <li key={tab.id}>
                    <button
                        onClick={() => setActiveTab(tab.id)}
                        className={`flex items-center gap-3 rounded-xl px-4 py-3 font-medium transition-all ${
                            activeTab === tab.id
                                ? "active bg-primary text-primary-content"
                                : "hover:bg-base-100"
                        }`}
                    >
                      {tab.name}
                    </button>
                  </li>
              ))}
            </ul>
          </div>

          <div className="p-2 border-t border-base-100 text-xs text-base-content/50 text-center">
            Base Sepolia Testnet
          </div>
        </aside>

        {/* 2. MAIN CONTENT AREA (Right) */}
        <div className="flex-1 flex flex-col overflow-hidden">
          {/* Navigation Header with Custom Wallet Connector */}
          <header className="navbar bg-base-200 justify-between px-8 border-b border-base-100 h-16 min-h-[4rem]">
            <div className="flex items-center gap-4">
              <h1 className="text-xl font-bold capitalize">
                {tabs.find((t) => t.id === activeTab)?.name.split(" ").slice(1).join(" ")}
              </h1>
            </div>

            <div>
              {isConnected ? (
                  <div className="flex items-center gap-3">
                    {/* Shortened User Address */}
                    <span className="font-mono text-sm bg-base-100 px-3 py-2 rounded-xl border border-base-100">
                  {address?.slice(0, 6)}...{address?.slice(-4)}
                </span>
                    {/* Disconnect Button */}
                    <button
                        onClick={() => disconnect()}
                        className="btn btn-error btn-outline btn-sm rounded-xl"
                    >
                      Disconnect
                    </button>
                  </div>
              ) : (
                  /* Dropdown listing only local browser-injected wallets */
                  <div className="dropdown dropdown-end">
                    <div
                        tabIndex={0}
                        role="button"
                        className="btn btn-primary btn-sm rounded-xl"
                    >
                      Connect Wallet
                    </div>
                    <ul
                        tabIndex={0}
                        className="dropdown-content menu bg-base-200 rounded-box z-[1] w-52 p-2 shadow-2xl mt-2 border border-base-100"
                    >
                      {connectors.map((connector) => (
                          <li key={connector.uid}>
                            <button
                                onClick={() => connect({ connector })}
                                className="py-2.5 font-medium rounded-lg"
                            >
                              {connector.name}
                            </button>
                          </li>
                      ))}
                    </ul>
                  </div>
              )}
            </div>
          </header>

          {/* Tab Content Display */}
          <main className="flex-1 overflow-y-auto p-8 bg-base-300">
            <div className="max-w-5xl mx-auto">
              {/* Faucet Tab */}
              {activeTab === "faucet" && (
                  <div className="card bg-base-200 shadow-xl p-6">
                    <h2 className="card-title mb-4">USDT / GOV Token Faucet</h2>
                    <p className="text-sm text-base-content/70 mb-6">
                      Claim free mock ERC-20 tokens to test and interact with all DeFi Labs playground applications on the Base Sepolia testnet.
                    </p>
                    <div className="flex gap-4">
                      <button className="btn btn-primary rounded-xl">Mint 1,000 USDT</button>
                      <button className="btn btn-secondary rounded-xl">Mint 100 GOV</button>
                    </div>
                  </div>
              )}

              {/* Money Streaming Tab */}
              {activeTab === "streaming" && (
                  <div className="card bg-base-200 shadow-xl p-6">
                    <h2 className="card-title mb-4">Real-Time Money Streaming</h2>
                    <p className="text-sm text-base-content/70 mb-6">
                      Set up constant, second-by-second token payment streams for payroll, vesting, or subscriptions.
                    </p>
                    {/* Empty State / Form Placeholder */}
                    <div className="border border-dashed border-base-100 rounded-2xl p-8 text-center text-base-content/50">
                      No active streams found. Connect your wallet to create your first stream.
                    </div>
                  </div>
              )}

              {/* Standard Under Construction fallback for other tabs */}
              {!["faucet", "streaming"].includes(activeTab) && (
                  <div className="hero bg-base-200 rounded-2xl p-12">
                    <div className="hero-content text-center">
                      <div className="max-w-md">
                        <h2 className="text-3xl font-bold">Under Construction</h2>
                        <p className="py-6 text-base-content/70">
                          The interface for this module will be connected as soon as the corresponding Diamond contract facet is deployed and verified.
                        </p>
                      </div>
                    </div>
                  </div>
              )}
            </div>
          </main>
        </div>
      </div>
  );
}