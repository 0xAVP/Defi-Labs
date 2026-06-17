
# DeFi Labs

DeFi Labs is a web dashboard where users can try out different decentralized finance (DeFi) tools in one place.

Unlike traditional setups where each tool is a separate contract, this project uses the Diamond Standard (EIP-2535). This means all features—such as streaming payments, flash loans, or NFT lending—run through a single contract address. The main contract acts like an API router for the blockchain.

## What this project will do

The goal is to build a single interface connected to a multi-tool contract on the Base Sepolia testnet. Once fully built, it will include:

* **Token Faucet:** A simple tool to claim mock USDT and GOV tokens to test the app.
* **Money Streaming:** A tool to set up token streams that the receiver can withdraw second-by-second (useful for salaries or vesting).
* **Flash Loans:** An interface to borrow and repay funds within a single transaction to see how atomic transactions work.
* **Liquid Staking:** A pool where you can stake tokens to earn mock rewards and get a liquid receipt token in return.
* **Options Trading:** A simplified covered call options market using real-time prices from Chainlink oracles.
* **Governance (ve-Tokenomics):** A locking mechanism where locking tokens for a longer time gives you more voting power.
* **NFT Lending:** A peer-to-peer loan market where you can use an ERC-721 NFT as collateral to borrow stablecoins, with automatic liquidation if the loan isn't repaid.

## Repository Structure

```text
/
├── frontend/                     # React + Vite SPA
└── contracts/                    # Foundry Smart Contracts Workspace
```

---

## 💻 Frontend (`frontend/`)

A client-side Single Page Application (SPA) with a responsive dashboard layout and custom wallet connection.

### Tech Stack
* **Build Tool:** Vite + React + TypeScript
* **Styling:** Tailwind CSS v4 & daisyUI v5 (configured as a Vite plugin via CSS-first architecture)
* **Web3 Integration:** `wagmi`, `viem`, and `@tanstack/react-query`

### How to Run
Navigate to the directory, install dependencies, and start the development server:
```bash
cd frontend
npm install
npm run dev
```
Open `http://localhost:5173/` in your browser.

---