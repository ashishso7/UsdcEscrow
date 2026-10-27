# UsdcEscrow

A secure USDC escrow contract on Arc Testnet. Parties lock USDC with a deadline; the owner arbitrates release or refund, and depositors can reclaim automatically after expiry.

Built with [Arc Studio](https://studio.arc.io)

---

## Tech Stack

- **Smart contracts:** Solidity 0.8.28, Foundry
- **Standards:** OpenZeppelin 5.6.1 (`Ownable2Step`, `ReentrancyGuard`, `SafeERC20`)
- **Chain:** Arc Testnet (Chain ID 5042002)
- **Token:** USDC (`0x3600000000000000000000000000000000000000`, 6 decimals)

---

## What It Does

- Any address can create an escrow by specifying a beneficiary, a USDC amount, and a deadline.
- The depositor funds the escrow by approving and calling `fund()`.
- The owner (arbitrator) can `release()` to the beneficiary or `refund()` to the depositor — before the deadline.
- After the deadline, the depositor may call `reclaim()` to recover their USDC without owner involvement.
- If the beneficiary becomes unreachable (e.g. blocklisted on Arc), the owner may call `fallbackRefund()` to return funds to the depositor at any time, or `emergencyRelease()` to push to the beneficiary after expiry.
- Ownership uses a two-step transfer; `renounceOwnership` is disabled.

---

## Development

### Prerequisites

- [Bun](https://bun.sh)
- [Foundry](https://book.getfoundry.sh)

### Install

```bash
bun install
```

### Build contracts

```bash
bun run contracts:build
```

### Test contracts

```bash
bun run contracts:test
```

### Run dev server

```bash
bun run dev
```

---

## Environment Variables

None required for contract development or testing.

---

## Deployed Contract

| Network | Address |
|---|---|
| Arc Testnet | `0x783014a50669adb7431f8404420444f6f236e74b` |

---

## Contract Files

| File | Purpose |
|---|---|
| `contracts/UsdcEscrow.sol` | Main escrow contract |
| `contracts/UsdcEscrow-design.md` | Design doc and security analysis |
| `contracts/test/UsdcEscrow.*.t.sol` | Foundry unit, fuzz, and invariant tests |
| `contracts/contract-metadata/UsdcEscrow.json` | Deployment metadata |
