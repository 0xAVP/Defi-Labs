// frontend/src/App.tsx
import { useState } from "react";
import { useAccount } from "wagmi";
import { DFL_TOKEN_ADDRESS } from "./config/addresses";

// Import Modular Components
import Sidebar from "./components/Sidebar";
import WalletConnect from "./components/WalletConnect";
import GasPortal from "./components/GasPortal";

// Import balance reader hook
import { useReadDflTokenBalanceOf } from "./generated";

export default function App() {
  const [activeTab, setActiveTab] = useState<string>("faucet");
  const { address } = useAccount();

  // Read user balance at the top level so we can share it between WalletConnect and future components
  const { data: dflBalance, refetch: refetchBalance } = useReadDflTokenBalanceOf({
    address: DFL_TOKEN_ADDRESS,
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  const tabs = [
    { id: "faucet", name: "🚰 Gas Portal (DFL Swap)" },
    { id: "flashloan", name: "⚡ Flash Loans" },
    { id: "staking", name: "🥩 Liquid Staking" },
    { id: "options", name: "📈 Options Trading" },
    { id: "governance", name: "🔒 Governance (ve)" },
    { id: "lending", name: "🖼️ NFT Lending" },
  ];

  return (
      <div className="flex h-screen bg-base-300 text-base-content">
        {/* 1. SIDEBAR NAVIGATION */}
        <Sidebar tabs={tabs} activeTab={activeTab} setActiveTab={setActiveTab} />

        {/* 2. MAIN HEADER & WORKSPACE */}
        <div className="flex-1 flex flex-col overflow-hidden">
          <header className="navbar bg-base-200 justify-between px-8 border-b border-base-100 h-16 min-h-[4rem]">
            <div className="flex items-center gap-4">
              <h1 className="text-xl font-bold capitalize">
                {tabs.find((t) => t.id === activeTab)?.name.split(" ").slice(1).join(" ")}
              </h1>
            </div>

            {/* Web3 Wallet Connect Component */}
            <WalletConnect dflBalance={dflBalance} refetchBalance={refetchBalance} />
          </header>

          {/* Workspace views based on the active tab */}
          <main className="flex-1 overflow-y-auto p-8 bg-base-300">
            <div className="max-w-5xl mx-auto">
              {activeTab === "faucet" && (
                  <GasPortal refetchBalance={refetchBalance} />
              )}

              {activeTab !== "faucet" && (
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