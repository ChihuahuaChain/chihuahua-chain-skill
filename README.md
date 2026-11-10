# chihuahua-chain skill

Everything a developer, or an AI agent, needs to build on the **Chihuahua chain**
(`chihuahua-1`), the CosmWasm + tokenfactory Cosmos meme chain behind the **$HUAHUA**
token. Install it and your coding agent has the chain's live network config, contract
workflows, dApp patterns, ecosystem apps, agent trading and operator runbooks on hand.

## Install

```bash
npx chihuahua-chain-skill
```

That copies the skill into `~/.claude/skills/chihuahua-chain` (set
`CLAUDE_SKILLS_DIR` to install elsewhere). Or copy this directory into your agent's
skills directory by hand. After install, the agent loads the skill automatically when
you work on Chihuahua.

> **Tip: invoke it explicitly.** Capable models are confident enough about Chihuahua
> to answer from memory, and memory is out of date since the v10 upgrades (October
> 2026: new gas floor, new SDK, new testnet). For guaranteed correctness, say *"use the
> chihuahua-chain skill to ..."*.

## What's inside

| File | Covers |
|------|--------|
| `SKILL.md` | Entry point: network quick reference + path picker. Start here. |
| `references/network.md` | Versions and upgrades, chain economics, endpoints, gas and the consensus minimum, fee burn, IBC status, CLI recipes, running a node, the woofnet-6 testnet, local devnet |
| `references/smart-contracts.md` | CosmWasm lifecycle: compile → optimize → permission check → store → instantiate → execute → migrate, and burning from a contract |
| `references/dapp-dev.md` | CosmJS (>= 0.39) after v10, Keplr/Huallet, wallet generation, gas and fees, sending HUAHUA, contracts, WebSocket events |
| `references/skip-go.md` | IBC via Osmosis (the live path), Skip Go routes, acquiring HUAHUA |
| `references/ecosystem.md` | The ecosystem dApps, Huahuaswap (x/liquidity) and its launchpad, tokenfactory and cw20 tokens, burning, NFTs (cw721) |
| `references/p2p-agents.md` | Huahua P2P: the contract, the x402 agent API, a tested CosmJS payer, safety rules for agents |
| `references/node-ops.md` | Operator path: Huahua Node Manager, validators, cosmovisor upgrades, IBC relayers |
| `assets/chain-info.json` | Drop-in Keplr/Huallet `experimentalSuggestChain` config |
| `assets/env.example` | Env vars (`CHAIN_ID`, `RPC`, `REST`, `GRPC`, `DENOM`, `GAS_PRICES`) |
| `scripts/chihuahua-env.sh` | `source` to load network vars + a `chihuahuad` wrapper (and `huahua woof` 🐕) |
| `scripts/install-chihuahuad.sh` | Build the `chihuahuad` CLI from source |

## Quick start (CLI)

```bash
source scripts/chihuahua-env.sh   # exports CHAIN_ID, RPC, REST, GRPC, gas, helpers
huahua_health                     # confirm the node is a synced chihuahua-1 node
huahua query bank balances chihuahua1...   # `huahua` = chihuahuad with --node preset
huahua woof                       # 🐕
```

## Network at a glance

| Field | Value |
|-------|-------|
| Chain ID | `chihuahua-1` |
| Token | HUAHUA: base denom `uhuahua`, 6 decimals (1 HUAHUA = 1,000,000 uhuahua) |
| Address prefix | `chihuahua1...` (SLIP-44 coin type 118) |
| CLI | `chihuahuad` |
| Primary RPC / REST | `https://rpc.chihuahua.wtf` / `https://api.chihuahua.wtf` |
| WebSocket | `wss://rpc.chihuahua.wtf/websocket` |
| Explorer | `https://explorer.chihuahua.wtf` |
| Gas price | **`500uhuahua` minimum, enforced in consensus** (x/feeburn, since v10.0.1); pad gas by 1.6 |
| Current binary | `v10.0.1` (Cosmos SDK v0.54.4, CometBFT v0.39.4, Go 1.26.5) |
| Testnet | `woofnet-6` with a faucet at `https://testnet-faucet.chihuahua.wtf` |
| Source | https://github.com/ChihuahuaChain/chihuahua |

Full endpoint lists (with fallbacks) and explorers live in `references/network.md`.

## Accuracy & freshness

Facts were checked against the live chain, the chain's source and its releases on
2026-11-10. The cosmos chain-registry lags (it still shows a v7 binary and no gas
floor), so the skill does not take its numbers from there. Things that drift are
flagged as "verify against source" inside the skill rather than hardcoded:

- **Binary version and upgrades:** check the
  [releases](https://github.com/ChihuahuaChain/chihuahua/releases) and
  [explorer.chihuahua.wtf/proposals](https://explorer.chihuahua.wtf/proposals) before
  running a node.
- **The gas floor** is a governance parameter: read it from
  `/chihuahua/feeburn/params`.
- **IBC paths:** only Osmosis is live today; check a client's status before relying on
  a channel.
- **Ecosystem contract addresses:** resolve the current address from the app or the
  chain, not from a tutorial.

Public RPC/REST/gRPC nodes rotate. If a call fails with a connection error, treat it
as a dead endpoint and fall back to another from the list.

## Learning resources (for humans)

- **[Area-52](https://area-52.io/)**: free, interactive course for CosmWasm + Rust
  smart contracts. The best on-ramp if Rust contracts are new to you.
- **[CosmWasm docs](https://cosmwasm.github.io/)**: the authoritative reference for
  contract authoring (entry points, storage, testing, IBC).
- **[CosmJS](https://github.com/cosmos/cosmjs)**: the TypeScript library for dApps;
  package READMEs are the API reference.
- **[create-interchain-app](https://github.com/hyperweb-io/create-interchain-app)**:
  `npx create-interchain-app` scaffolds a Next.js + multi-wallet Cosmos dApp (set the
  gas price to 500uhuahua; see `references/dapp-dev.md`).
- **[interchain-kit](https://github.com/hyperweb-io/interchain-kit)**: multi-wallet
  adapter for React/Vue that hands an offline signer to CosmJS.
- **[Huahua Node Manager](https://github.com/ChihuahuaChain/huahua-node-manager)**:
  one-command node setup with a live dashboard.
- **[Chiwawasm](https://github.com/ChihuahuaChain/Chiwawasm)**: Chihuahua's own example
  contracts (AMM, cw20 minting, burn), to study rather than deploy as-is.

## Validated

Two rounds of with-skill vs. baseline evals, both 100% clean on the skill side
(baseline 92% → 83% as cases hardened). The November 2026 update was checked by
running its code against the chain: CosmJS 0.39 reads, simulate and broadcast on
v10.0.1, the gas padding, raw WebSocket subscriptions, Skip Go routing to HUAHUA, and
the Huahua P2P x402 payer end to end on woofnet-6.
