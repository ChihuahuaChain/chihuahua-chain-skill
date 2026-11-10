---
name: chihuahua-chain
description: >-
  Everything needed to build on the Chihuahua chain (chihuahua-1), the CosmWasm
  + tokenfactory Cosmos meme chain behind $HUAHUA (base denom uhuahua, 6
  decimals). Use for ANY dev, agent or operator task on Chihuahua: endpoints and
  chain ID; gas, the 500uhuahua consensus minimum, "insufficient fee" or out of
  gas; the woofnet-6 testnet and faucet; CosmWasm contracts; wallets, sending
  HUAHUA, display vs base units; dApps with CosmJS and Keplr/Huallet; meme tokens
  (tokenfactory, Huahuaswap launchpad, cw20), NFTs, burning; Huahuaswap; trading
  on Huahua P2P, incl. AI agents paying with x402; IBC and Skip Go; nodes,
  validators, relayers (Huahua Node Manager, upgrades). Trigger on "Chihuahua
  chain", "HUAHUA", "chihuahua-1", "uhuahua", "chihuahuad", "woofnet",
  "Huahuaswap" or "Huahua P2P", even when no tool is named, as long as the work
  targets Chihuahua. Do NOT trigger for other Cosmos chains (Osmosis, Cosmos Hub,
  Juno) or generic CosmWasm/IBC questions that never reference Chihuahua.
---

# Building on Chihuahua Chain

Chihuahua (`chihuahua-1`) is a Cosmos SDK + CosmWasm Proof-of-Stake chain. Native
token: **HUAHUA** (base denom `uhuahua`, 6 decimals: 1 HUAHUA = 1,000,000 uhuahua).
Address prefix: `chihuahua1...`. Since the v10 upgrades (October 2026) it runs
Cosmos SDK v0.54 and CometBFT v0.39, enforces a **minimum gas price in consensus**,
burns half of every transaction fee, and has zero inflation.

This skill bundles the chain's live network config plus deep-dive guides for each
build path. **Start here, then read the one reference file that matches the task.**
Don't load every reference: progressive disclosure keeps context lean.

## Network quick reference (checked 2026-11-10; endpoints drift, verify before trusting one)

| Field | Value |
|-------|-------|
| Chain ID | `chihuahua-1` |
| Address prefix (bech32) | `chihuahua` |
| Coin type (SLIP-44) | `118` |
| Base denom | `uhuahua` (micro) |
| Display denom | `huahua`: 1 HUAHUA = 1e6 uhuahua |
| CLI daemon | `chihuahuad` (node home `~/.chihuahuad`) |
| Chain version | **v10.0.1** (Cosmos SDK v0.54.4, CometBFT v0.39.4, ibc-go v11, wasmd v0.70 / wasmvm v3; builds with Go 1.26.5) |
| Source / releases | https://github.com/ChihuahuaChain/chihuahua |
| Primary RPC | `https://rpc.chihuahua.wtf` |
| Primary REST/LCD | `https://api.chihuahua.wtf` |
| gRPC | `grpc.chihuahua.wtf:443` |
| WebSocket | `wss://rpc.chihuahua.wtf/websocket` |
| Explorer | https://explorer.chihuahua.wtf (`/tx/<HASH>`, `/account/<addr>`, `/proposals`) |
| Minimum gas price | **`500uhuahua` per gas, enforced in consensus** (x/feeburn `min_gas_prices`, set by governance) |
| Recommended CLI flags | `--gas auto --gas-adjustment 1.6 --gas-prices 500uhuahua` |
| Testnet | `woofnet-6`: RPC `https://testnet-rpc.chihuahua.wtf`, REST `https://testnet-api.chihuahua.wtf`, faucet `https://testnet-faucet.chihuahua.wtf` |

Transactions paying less than 500 uhuahua per gas are rejected by every node,
whatever a node's local `minimum-gas-prices` says. Read the live floor before
hardcoding it, since governance can change it:
`curl -s https://api.chihuahua.wtf/chihuahua/feeburn/params`.

The `chihuahua.wtf` endpoints are run by the chain itself; the **cosmos
chain-registry** (`chihuahua/chain.json`) lists the rest, but it lags: several
providers there no longer serve Chihuahua. If a call fails with a connection error,
treat it as a dead endpoint, not a bug in your code, and fall back to another node
from [references/network.md](references/network.md). Always confirm the chain ID a
node reports (`curl -s <rpc>/status | jq -r .result.node_info.network`) equals
`chihuahua-1` before trusting it.

## Pick your path

| You want to... | Read |
|----------------|------|
| Connect to endpoints, set env vars, understand gas, fees, burn and denoms, use the testnet | [references/network.md](references/network.md) |
| Write, compile, store, instantiate, execute, or query a **CosmWasm contract** | [references/smart-contracts.md](references/smart-contracts.md) |
| Build a **dApp / frontend / bot**: CosmJS, generate a wallet, sign txs, add the chain to Keplr/Huallet | [references/dapp-dev.md](references/dapp-dev.md) |
| Move HUAHUA **cross-chain** (IBC via Osmosis, Skip Go) or **acquire HUAHUA** | [references/skip-go.md](references/skip-go.md) |
| Use **Huahuaswap** and its launchpad, launch a **meme token** (tokenfactory or cw20), mint **NFTs** (cw721), **burn** HUAHUA, find the ecosystem dApps | [references/ecosystem.md](references/ecosystem.md) |
| Trade on **Huahua P2P** (escrowed peer-to-peer offers), from code or as an **AI agent paying with x402** | [references/p2p-agents.md](references/p2p-agents.md) |
| Run a **node**, a **validator** or an **IBC relayer** (Huahua Node Manager, snapshots, cosmovisor, upgrades) | [references/node-ops.md](references/node-ops.md) |

## Bundled assets & scripts

- [`assets/chain-info.json`](assets/chain-info.json): ready-to-use Keplr/Huallet
  `experimentalSuggestChain` config object. Drop it into a dApp to register the
  chain in the user's wallet.
- [`assets/env.example`](assets/env.example): environment variables (`CHAIN_ID`,
  `RPC`, `REST`, `GRPC`, `DENOM`, `GAS_PRICES`) for CLI and scripting. Copy to
  `.env` and `source` it.
- [`scripts/chihuahua-env.sh`](scripts/chihuahua-env.sh): `source` this to export
  the network vars and a `chihuahuad`-with-node-flags wrapper into your shell.
  (Run `huahua woof` for a friendly reminder. 🐕)
- [`scripts/install-chihuahuad.sh`](scripts/install-chihuahuad.sh): build the
  `chihuahuad` CLI from source at the current release (`v10.0.1`, Go 1.26.5). On
  Linux, the release page also ships static amd64 and arm64 binaries.

## Operating principles

1. **Never hardcode a fee in display units.** Fees, balances, and amounts on-chain
   are always in `uhuahua`. A user saying "send 5 HUAHUA" means `5000000uhuahua`.
   Convert at the boundary and label it, so nobody fat-fingers a 1,000,000x error.
2. **Pay at least the consensus minimum, and pad the gas.** 500 uhuahua per gas is
   the floor. Simulations underestimate on this chain (a measured send used 41%
   more gas than simulated), and a transaction that runs out of gas still pays its
   fee. Use `--gas-adjustment 1.6`, or simulation × 1.6 + 30,000 in code; never
   CosmJS's default `"auto"` (1.4x).
3. **Read before write.** Before any state-changing tx (`store`, `instantiate`,
   `execute`, `tx send`), dry-run the query side first (`query bank balances`,
   `query wasm contract-state`) so you confirm the node, address, and chain ID are
   right. Broadcasting to the wrong chain ID just fails; broadcasting a wrong
   amount spends real funds.
4. **Confirm permissions before deploying a contract.** `code_upload_access` is
   open to everybody today, but it is a governance parameter.
   [references/smart-contracts.md](references/smart-contracts.md) shows how to
   check it (`chihuahuad query wasm params`) and how to deploy under either regime.
5. **Mainnet is real money.** Rehearse on the public **woofnet-6 testnet** (free
   HUAHUA from its faucet, same v10.0.1 binary, wasm upload open) or on a local
   single-node chain, then promote to `chihuahua-1`. See
   [references/network.md](references/network.md#testnet-woofnet-6).
