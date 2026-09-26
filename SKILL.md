---
name: chihuahua-chain
description: >-
  Everything needed to build on the Chihuahua chain (chihuahua-1), the CosmWasm
  + tokenfactory Cosmos meme chain behind the $HUAHUA token (base denom uhuahua,
  6 decimals). Use for ANY dev, integration, or operator task on Chihuahua:
  RPC/REST/gRPC/WebSocket endpoints and chain ID; gas price / "insufficient fee"
  / failed broadcasts; deploying, instantiating, executing, or querying CosmWasm
  contracts and code-upload permissions; generating a wallet, sending HUAHUA, or
  reading balances in display vs base units; dApps with CosmJS and Keplr/Leap;
  launching a meme token (tokenfactory denom or cw20) or NFTs (cw721); the native
  DEX Huahuaswap; bridging or acquiring HUAHUA via IBC or Skip Go; or running a
  validator or IBC relayer. Trigger on "Chihuahua chain", "HUAHUA", "chihuahua-1",
  "uhuahua", or "chihuahuad", even when no exact tool is named, as long as the
  work targets Chihuahua. Do NOT trigger for other Cosmos chains (Osmosis, Cosmos
  Hub, Juno) or generic CosmWasm/IBC questions that never reference Chihuahua.
---

# Building on Chihuahua Chain

Chihuahua (`chihuahua-1`) is a Cosmos SDK + CosmWasm Proof-of-Stake chain. Native
token: **HUAHUA** (base denom `uhuahua`, 6 decimals → 1 HUAHUA = 1,000,000 uhuahua).
Address prefix: `chihuahua1...`. It speaks IBC to 30+ Cosmos chains and is reachable
from Skip Go for cross-chain transfers and swaps.

This skill bundles the chain's live network config plus deep-dive guides for each
build path. **Start here, then read the one reference file that matches the task.**
Don't load every reference — progressive disclosure keeps context lean.

## Network quick reference (endpoints drift — verify before trusting one)

| Field | Value |
|-------|-------|
| Chain ID | `chihuahua-1` |
| Address prefix (bech32) | `chihuahua` |
| Coin type (SLIP-44) | `118` |
| Base denom | `uhuahua` (micro) |
| Display denom | `huahua` — 1 HUAHUA = 1e6 uhuahua |
| CLI daemon | `chihuahuad` (node home `~/.chihuahuad`) |
| Source / releases | https://github.com/ChihuahuaChain/chihuahua |
| Primary RPC | `https://rpc.chihuahua.wtf` |
| Primary REST/LCD | `https://api.chihuahua.wtf` |
| WebSocket | `wss://rpc.chihuahua.wtf/websocket` |
| Explorer | https://explorer.chihuahua.wtf (`/tx/<HASH>`, `/account/<addr>`, `/proposals`) |
| Gas price (uhuahua/gas) | chain min `100`, low `500`, avg `1250`, high `2000` |
| Recommended fee | `--gas auto --gas-adjustment 1.4 --gas-prices 1250uhuahua` |

The `chihuahua.wtf` endpoints are run by the chain itself; the **cosmos
chain-registry** (`chihuahua/chain.json`) lists the rest, but it lags: several
providers there no longer serve Chihuahua. Public RPC/REST/gRPC nodes come and go,
so if a call fails with a connection error, treat it as a dead endpoint, not a bug
in your code — fall back to another node from the list in
[references/network.md](references/network.md). Always confirm the chain ID a node
reports (`curl -s <rpc>/status | jq -r .result.node_info.network`) equals
`chihuahua-1` before trusting it.

## Pick your path

| You want to... | Read |
|----------------|------|
| Connect to endpoints, set env vars, run/sync a node, understand gas & denoms | [references/network.md](references/network.md) |
| Write, compile, store, instantiate, execute, or query a **CosmWasm contract** | [references/smart-contracts.md](references/smart-contracts.md) |
| Build a **dApp / frontend** — scaffold one fast (create-interchain-app) or wire CosmJS by hand, generate a wallet, sign txs, add the chain to Keplr/Leap | [references/dapp-dev.md](references/dapp-dev.md) |
| Move HUAHUA **cross-chain** (deposit/withdraw, swaps, IBC) or **acquire HUAHUA** with **Skip Go** | [references/skip-go.md](references/skip-go.md) |
| Use **Huahuaswap**, launch a **meme token** (tokenfactory or cw20), mint **NFTs** (cw721) | [references/ecosystem.md](references/ecosystem.md) |
| Run a **validator** or an **IBC relayer** (Hermes) for/to Chihuahua (operator path) | [references/node-ops.md](references/node-ops.md) |

## Bundled assets & scripts

- [`assets/chain-info.json`](assets/chain-info.json) — ready-to-use Keplr/Leap
  `experimentalSuggestChain` config object. Drop it into a dApp to register the
  chain in the user's wallet.
- [`assets/env.example`](assets/env.example) — environment variables (`CHAIN_ID`,
  `RPC`, `REST`, `GRPC`, `DENOM`, `GAS_PRICES`) for CLI and scripting. Copy to
  `.env` and `source` it.
- [`scripts/chihuahua-env.sh`](scripts/chihuahua-env.sh) — `source` this to export
  the network vars and a `chihuahuad`-with-node-flags wrapper into your shell.
  (Run `huahua woof` for a friendly reminder. 🐕)
- [`scripts/install-chihuahuad.sh`](scripts/install-chihuahuad.sh) — build the
  `chihuahuad` CLI from source (Go) at the latest release (`v9.0.7`, Go 1.23.9).

## Operating principles

1. **Never hardcode a fee in display units.** Fees, balances, and amounts on-chain
   are always in `uhuahua`. A user saying "send 5 HUAHUA" means `5000000uhuahua`.
   Convert at the boundary and label it, so nobody fat-fingers a 1,000,000x error.
2. **Read before write.** Before any state-changing tx (`store`, `instantiate`,
   `execute`, `tx send`), dry-run the query side first (`query bank balances`,
   `query wasm contract-state`) so you confirm the node, address, and chain ID are
   right. Broadcasting to the wrong chain ID just fails; broadcasting a wrong
   amount spends real funds.
3. **Confirm permissions before deploying a contract.** Chihuahua's CosmWasm
   `code_upload_access` can be permissionless or governance-gated depending on the
   chain's current params. [references/smart-contracts.md](references/smart-contracts.md)
   shows how to check (`chihuahuad query wasm params`) and how to deploy under
   either regime — don't assume `store-code` will be open.
4. **Mainnet is real money.** There's no widely-hosted public testnet; the safe
   sandbox is a **local single-node chain** (see network.md → "Local devnet"). Do
   first deploys and risky experiments there, then promote to `chihuahua-1`.
