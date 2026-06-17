# DeFi Labs (EIP-2535 Diamond)

DeFi Labs is a single-page web dashboard where users can interact with various decentralized finance (DeFi) tools in one place. 

Instead of deploying separate smart contracts for each tool, this project uses the Diamond Standard (EIP-2535). All features—like payment streaming, flash loans, or NFT lending—run through a single contract address (the Diamond Proxy), which acts as an API router for the blockchain.

---

## 🛠️ Current Status & Implemented Features

### 1. Core Diamond Infrastructure (EIP-2535)
* **Single Proxy Entrypoint:** The core `Diamond.sol` proxy intercepts all function calls and forwards them to the respective logic facets using low-level EVM `delegatecall`.
* **Access Control & Upgrades:** Upgrades are handled via `DiamondCutFacet` (EIP-2535 standard). Custom errors (`Diamond__FunctionDoesNotExist`) are used to save deployment and execution gas.
* **Collision-Safe Storage:** Uses the **App Storage** pattern (conforming to EIP-7201 structured storage). All variables for all facets are declared in a single, packed, and strictly slot-documented struct inside `LibAppStorage.sol` to prevent storage collisions.

### 2. DFL Ecosystem Token (`DFLToken.sol`)
* Our real, production-ready utility and governance token.
* Inherits from OpenZeppelin's `ERC20`, `ERC20Permit` (EIP-2612 gasless approvals), `ERC20Burnable`, and `AccessControl`.
* Minting rights are strictly restricted to the core `Diamond` proxy contract via `MINTER_ROLE`.

### 3. Gas Liquidity Portal (`LiquidityPortalFacet.sol` & `AdminFacet.sol`)
* **Incentivized Deposits (Mint):** Users deposit native testnet gas (ETH/MATIC) on any chain to provide liquidity for the future gas bridge. In return, the contract mints them DFL tokens.
* **Dynamic Scarcity Math:** Payout rates are calculated dynamically based on the current pool reserves vs. target balances. If a pool has a high deficit, depositing gas is heavily rewarded with extra DFL.
* **Economic Loop Protection (Redeem):** Users can burn DFL locally to withdraw native gas. To prevent exploit loops (depositing and immediately withdrawing to print DFL), the contract applies a 5% withdraw fee (spread) and scales withdraw difficulty based on pool deficit.

### 4. Advanced Testing & Local Deployment
* **16 passing tests** in Foundry, divided into isolated `/unit` and `/integration` suites.
* Tests cover standard ERC-20 transfers, advanced cryptographic EIP-712 signature verification (Permit), access control containment, and mathematical validation of the dynamic pool deficit and withdrawal penalties.
* Full end-to-end local deployment configured on an **Anvil** node (Chain ID `31337`) using `DeployDiamond.s.sol`.

### 5. Frontend & Web3 Integration (`frontend/`)
* **Vite + React + TS** Single Page Application styled with **Tailwind CSS v4** & **daisyUI v5**.
* **No Reown (WalletConnect) dependency:** Pure browser-injected wallet detection (via Wagmi's `injected()` connector). Avoids any centralized cloud project ID requirements.
* **Automated ABI Syncing:** Powered by `@wagmi/cli` and its `foundry()` & `react()` plugins. Running a single command automatically parses compiled Solidity artifacts and generates typed React hooks.
* **Interactive UI:** Features real-time balance tracking, dynamic quote calculations from the contract, automated ERC-20 `allowance` checks, and a smooth "Approve DFL Spending" $\rightarrow$ "Burn DFL & Redeem Gas" transaction flow.