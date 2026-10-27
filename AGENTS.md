# UsdcEscrow

> Built with Arc Studio - money-powered apps in minutes

This is the **project memory** - what Arc Studio remembers about building this app. It helps future agents (or humans) understand and extend the project.

---

## What This App Does

USDC escrow contract on Arc Testnet. Depositors lock USDC for a beneficiary with a deadline; the owner (arbitrator) can release or refund before expiry; depositors can reclaim after expiry. Full lifecycle: Pending → Funded → Released | Refunded.

## Deployed Contracts

| Contract | Network | Address | Explorer |
|---|---|---|---|
| UsdcEscrow | Arc Testnet | 0x783014a50669adb7431f8404420444f6f236e74b | https://explorer.testnet.arc.io/address/0x783014a50669adb7431f8404420444f6f236e74b |

Deployed: 2026-10-27. TX: 0x92a75bfb5c833b25bf70906cce5775f3a2048aa1ae0039f084f496725d678134

## Tech Stack

- Frontend: React 18, Vite, TypeScript, Tailwind CSS
- Web3: wagmi v2, viem v2, ConnectKit
- Contracts: Solidity 0.8.28 + Foundry. Sources in `contracts/`, unit tests in `contracts/test/*.t.sol`. Build with `bun run contracts:build` (`forge build`), test with `bun run contracts:test` (`forge test`).
- Wallet: injected (MetaMask, etc.)
- Chain: Arc Testnet (Chain ID: 5042002, imported from `viem/chains`)
- Token: USDC (6 decimals) (Address: 0x3600000000000000000000000000000000000000, Chain: Arc Testnet)
- Toasts: Sonner

## Key Files

- `src/App.tsx` - Main application logic
- `src/components/` - UI components
- `src/config.ts` - wagmi config (chains, connectors, transports)

## To Run

```bash
bun install
bun run dev
```
