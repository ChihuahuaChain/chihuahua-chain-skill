# chihuahua-chain skill

Everything a developer needs to build on the **Chihuahua chain** (`chihuahua-1`) —
the CosmWasm + tokenfactory Cosmos meme chain behind the **$HUAHUA** token. Install
it and your coding agent has the chain's live network config, contract workflows,
dApp patterns, ecosystem apps, and operator runbooks on hand.

## Install

Pick whichever fits your setup:

- **Packaged skill:** double-click `chihuahua-chain.skill` (in the parent dir), or
  import it through your skills UI.
- **Folder:** copy this `chihuahua-chain/` directory into your agent's skills
  directory (e.g. `~/.claude/skills/`).

After install, the agent loads the skill automatically when you work on Chihuahua.

> **Tip — invoke it explicitly.** Capable models are confident enough about Chihuahua
> to answer from memory (and sometimes get the gas price wrong). For guaranteed
> correctness, say *"use the chihuahua-chain skill to ..."*. That's where it reliably
> catches the chain-specific mistakes a bare model makes.

## What's inside

| File | Covers |
|------|--------|
| `SKILL.md` | Entry point: network quick-reference + path picker. Start here. |
| `references/network.md` | RPC / REST / gRPC / WebSocket endpoints, chain ID, gas, denoms, CLI recipes, running a node, local devnet |
| `references/smart-contracts.md` | CosmWasm lifecycle: compile → optimize → permission check → store → instantiate → execute → migrate |
| `references/dapp-dev.md` | CosmJS, Keplr/Leap, programmatic wallet generation, sending HUAHUA, live WS subscriptions |
| `references/skip-go.md` | Cross-chain transfers/swaps and acquiring HUAHUA via Skip Go / IBC |
| `references/ecosystem.md` | Huahuaswap DEX, launching a meme token (tokenfactory denom or cw20), NFTs (cw721) |
| `references/node-ops.md` | Operator path: becoming a validator (Cosmovisor, anti-slash) and running a Hermes IBC relayer |
| `assets/chain-info.json` | Drop-in Keplr/Leap `experimentalSuggestChain` config |
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
| Token | HUAHUA — base denom `uhuahua`, 6 decimals (1 HUAHUA = 1,000,000 uhuahua) |
| Address prefix | `chihuahua1...` (SLIP-44 coin type 118) |
| CLI | `chihuahuad` |
| Primary RPC / REST | `https://rpc.chihuahua.wtf` / `https://api.chihuahua.wtf` |
| WebSocket | `wss://rpc.chihuahua.wtf/websocket` |
| Explorer | `https://explorer.chihuahua.wtf` |
| Gas price | `1250uhuahua` average (chain minimum `100`, low 500, high 2000) — **not** the generic `0.025` |
| Current binary | `v9.0.7` (Go 1.23.9) — verify latest before syncing a node |
| Source | https://github.com/ChihuahuaChain/chihuahua |

Full endpoint lists (with fallbacks) and explorers live in `references/network.md`.

## Accuracy & freshness

Chain facts are grounded in the [cosmos chain-registry](https://github.com/cosmos/chain-registry/tree/master/chihuahua).
Two things drift and are intentionally flagged as "verify against source" inside the
skill rather than hardcoded:

- **Binary version** — the cosmos chain-registry pin lags the live chain. The current
  release is **v9.0.7** (Go 1.23.9); always check the
  [releases](https://github.com/ChihuahuaChain/chihuahua/releases) and the latest
  upgrade proposal before running a node.
- **Ecosystem contract addresses** (Huahuaswap pools/router) — resolve the current
  address from the app or by querying the chain, not from a tutorial.

Public RPC/REST/gRPC nodes rotate constantly. If a call fails with a connection
error, treat it as a dead endpoint and fall back to another from the list.

## Learning resources (for humans)

New to Cosmos / CosmWasm and want to level up beyond what the skill automates?

- **[Area-52](https://area-52.io/)** — free, interactive, game-like course for
  CosmWasm + Rust smart contracts. The best on-ramp if Rust contracts are new to you.
- **[CosmWasm docs](https://cosmwasm.github.io/)** — the authoritative reference for
  contract authoring (entry points, storage, testing, IBC).
- **[CosmJS](https://github.com/cosmos/cosmjs)** — the TypeScript library for dApps;
  package READMEs are the API reference.
- **[create-interchain-app](https://github.com/hyperweb-io/create-interchain-app)** —
  `npx create-interchain-app` scaffolds a full Next.js + multi-wallet Cosmos dApp;
  Chihuahua works via the chain-registry. Fastest way to a working web app (see
  `references/dapp-dev.md`).
- **[interchain-kit](https://github.com/hyperweb-io/interchain-kit)** — the standalone
  multi-wallet adapter for React/Vue (Cosmos Kit 3.0). Add managed wallet connection
  to an *existing* app; exposes an offline signer that plugs into CosmJS.
- **[Chiwawasm](https://github.com/ChihuahuaChain/Chiwawasm)** — Chihuahua's own
  example contracts (AMM, cw20 minting, burn). Reference implementations to study,
  not deploy as-is (dated tooling — see `references/ecosystem.md`).

## Validated

Two rounds of with-skill vs. baseline evals, both 100% clean on the skill side
(baseline 92% → 83% as cases hardened). The skill's measured value: deterministic
gas pricing, resilient endpoint fallbacks, and ecosystem specifics (Huahuaswap,
tokenfactory) the bare model gets wrong or vague about.
