// frontend/src/components/Sidebar.tsx
interface Tab {
    id: string;
    name: string;
}

interface SidebarProps {
    tabs: Tab[];
    activeTab: string;
    setActiveTab: (id: string) => void;
}

export default function Sidebar({ tabs, activeTab, setActiveTab }: SidebarProps) {
    return (
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
    );
}