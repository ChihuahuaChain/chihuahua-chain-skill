# Chihuahua Network Reference

Everything about connecting to `chihuahua-1`: endpoints, denoms, gas, the CLI, and
running a node. Endpoints were checked live in September 2026; the cosmos
chain-registry (`chihuahua/chain.json`) still lists several providers that have since
dropped the chain. Endpoints are operated by independent validators and rotate — if
one is down, move to the next, and prefer the `chihuahua.wtf` ones.

## Table of contents
- [Chain identity](#chain-identity)
- [Denominations & gas](#denominations--gas)
- [RPC endpoints](#rpc-endpoints)
- [REST / LCD endpoints](#rest--lcd-endpoints)
- [gRPC endpoints](#grpc-endpoints)
- [WebSocket (events & subscriptions)](#websocket-events--subscriptions)
- [Explorers](#explorers)
- [The chihuahuad CLI](#the-chihuahuad-cli)
- [Common CLI recipes](#common-cli-recipes)
- [Multisig accounts](#multisig-accounts)
- [Running a full node](#running-a-full-node)
- [Local devnet (your safe sandbox)](#local-devnet-your-safe-sandbox)

## Chain identity

| Field | Value |
|-------|-------|
| Chain ID | `chihuahua-1` |
| Bech32 prefix | `chihuahua` (account), `chihuahuavaloper` (validator), `chihuahuavalcons` (consensus) |
| SLIP-44 coin type | `118` |
| Daemon | `chihuahuad` |
| Node home | `$HOME/.chihuahuad` |
| Source | https://github.com/ChihuahuaChain/chihuahua |
| Current binary | `v9.0.7` (Go 1.23.9; cosmos-sdk v0.50.x, cometbft v0.38.x) — always confirm the latest [release](https://github.com/ChihuahuaChain/chihuahua/releases) and the active upgrade height before syncing |

> The recommended version in the registry can lag the live network. Before running
> a node, check https://github.com/ChihuahuaChain/chihuahua/releases and the chain's
> latest upgrade governance proposal for the version the active validator set is on.

## Denominations & gas

- **Base denom:** `uhuahua` — this is what every on-chain amount uses.
- **Display denom:** `huahua` — exponent 6. `1 HUAHUA = 1_000_000 uhuahua`.
- **Symbol:** HUAHUA.

Gas prices (in `uhuahua` per unit of gas). The **chain's current minimum** is
`100uhuahua` (what validators set as `minimum-gas-prices` in `app.toml`); the
registry's wallet tiers sit above it:

| Tier | Price |
|------|-------|
| Chain minimum (node `minimum-gas-prices`) | `100uhuahua` |
| Low | `500uhuahua` |
| Average | `1250uhuahua` |
| High | `2000uhuahua` |

Any price at or above `100uhuahua` is accepted; `1250uhuahua` (average) is a safe
default that clears the minimum with margin. The thing to never do is fall back to
the generic Cosmos `0.025` — that's ~4,000x below the Chihuahua minimum and gets
rejected as `insufficient fee`.

Recommended flags for any tx (let the node estimate gas, pad it, pay the average
price):

```bash
--gas auto --gas-adjustment 1.4 --gas-prices 1250uhuahua
```

If a tx fails with `out of gas`, raise `--gas-adjustment` (e.g. 1.6). If it fails
with `insufficient fee`, raise `--gas-prices` toward the high tier.

## RPC endpoints

CometBFT/Tendermint RPC (port surface for `--node`, status, blocks, tx broadcast):

```
https://rpc.chihuahua.wtf
https://chihuahua-rpc.kleomedes.network
https://rpc.chihuahua.validatus.com
https://chihuahua.api.pocket.network
```

Health check (returns `chihuahua-1` if the node is on the right chain and synced):

```bash
curl -s https://rpc.chihuahua.wtf/status | jq '{network: .result.node_info.network, height: .result.sync_info.latest_block_height, catching_up: .result.sync_info.catching_up}'
```

## REST / LCD endpoints

Cosmos SDK REST API (for HTTP/JSON queries, e.g. `/cosmos/bank/v1beta1/balances/<addr>`):

```
https://api.chihuahua.wtf
https://chihuahua-api.kleomedes.network
```

Example — query a balance over REST:

```bash
curl -s "https://api.chihuahua.wtf/cosmos/bank/v1beta1/balances/chihuahua1youraddresshere" | jq
```

## gRPC endpoints

For `grpc`/protobuf clients and high-throughput indexing (CosmJS does not need gRPC:
it talks to the RPC endpoints above). Public gRPC for Chihuahua is scarce — most
providers in the chain-registry no longer serve it, and this was the only one that
answered in September 2026. Check it before relying on it, and run your own node
(`:9090`) for anything serious:

```
grpc.chihuahua.validatus.com:443
```

## WebSocket (events & subscriptions)

CometBFT exposes a JSON-RPC-over-WebSocket endpoint at `/websocket` on every RPC
node. There is no separate WS host — append `/websocket` to an RPC URL and switch
the scheme to `wss://`:

```
wss://rpc.chihuahua.wtf/websocket
wss://chihuahua-rpc.kleomedes.network/websocket
```

Subscribe to new blocks (raw protocol — most clients wrap this for you):

```json
{ "jsonrpc": "2.0", "method": "subscribe", "id": 1,
  "params": { "query": "tm.event='NewBlock'" } }
```

Other useful queries: `tm.event='Tx'` (every tx), or filter by an event attribute,
e.g. `tm.event='Tx' AND transfer.recipient='chihuahua1...'` to watch deposits to an
address. CosmJS's `Tendermint37Client`/`Tendermint34Client` and `WebsocketClient`
handle the framing; see [dapp-dev.md](dapp-dev.md). Note CometBFT WS subscriptions
are best-effort and can drop under load — for guaranteed delivery, poll
`/tx_search` or block results as a backstop.

## Explorers

```
https://explorer.chihuahua.wtf
https://atomscan.com/chihuahua
https://explorer.stavr.tech/Chihua-Mainnet
https://staking-explorer.com/explorer/chihuahua
https://ezstaking.app/chihuahua
https://explorer.nodeshub.online/chihuahua/
```

[explorer.chihuahua.wtf](https://explorer.chihuahua.wtf) is the chain's own explorer:
it reads straight from a full node, so it never lags the chain. Its URLs are stable
and easy to hand to (or build for) a human:

| What | URL |
|------|-----|
| Transaction | `https://explorer.chihuahua.wtf/tx/<HASH>` |
| Block | `https://explorer.chihuahua.wtf/block/<HEIGHT>` |
| Account or contract | `https://explorer.chihuahua.wtf/account/<chihuahua1...>` (contracts show their label) |
| Validator | `https://explorer.chihuahua.wtf/validator/<chihuahuavaloper1...>` |
| Proposal | `https://explorer.chihuahua.wtf/proposal/<ID>` |
| Assets (native, IBC, tokenfactory) | `https://explorer.chihuahua.wtf/assets` |
| Chain parameters | `https://explorer.chihuahua.wtf/parameters` |

Use it to confirm a tx hash landed, to check an address or contract, to follow
upgrade proposals (the version + height your node must be on) and wasm-permission
governance, and to see which `ibc/<HASH>` voucher a transferred asset became.

Two things it doesn't have a page for, and the CLI answers directly:

```bash
# code IDs and the contracts instantiated from one (resolve a *current* address)
chihuahuad query wasm list-code --node "$NODE"
chihuahuad query wasm list-contract-by-code <CODE_ID> --node "$NODE"
# IBC channels (channel IDs, counterparty, state) before standing up a relayer
chihuahuad query ibc channel channels --node "$NODE" --output json \
  | jq '.channels[] | {channel_id, state, counterparty}'
```

## The chihuahuad CLI

Install from source. `v9.0.7` builds with **Go 1.23.9** (confirm against `go.mod` in
the repo for the version you're checking out). The
[`scripts/install-chihuahuad.sh`](../scripts/install-chihuahuad.sh) helper does this
for you. Manual path:

```bash
git clone https://github.com/ChihuahuaChain/chihuahua
cd chihuahua
git fetch --tags
git checkout v9.0.7     # latest release; or the current consensus version
make install            # installs chihuahuad to $GOPATH/bin
chihuahuad version      # verify
```

Point the CLI at a public node so you don't need to run your own:

```bash
export NODE=https://rpc.chihuahua.wtf
export CHAIN_ID=chihuahua-1
# every command below passes --node "$NODE" --chain-id "$CHAIN_ID"
```

Or `source` [`scripts/chihuahua-env.sh`](../scripts/chihuahua-env.sh), which sets
these and gives you a `huahua` wrapper that injects the flags automatically.

## Common CLI recipes

Keys (test the workflow on the local devnet first — these manage real funds on
mainnet):

```bash
chihuahuad keys add mykey                       # create
chihuahuad keys add mykey --recover             # import from mnemonic
chihuahuad keys show mykey -a                    # print chihuahua1... address
chihuahuad keys list
```

Query balance:

```bash
chihuahuad query bank balances chihuahua1... --node "$NODE"
```

Send HUAHUA (amount is in uhuahua — 5 HUAHUA = 5000000uhuahua):

```bash
chihuahuad tx bank send mykey chihuahua1recipient... 5000000uhuahua \
  --chain-id chihuahua-1 --node "$NODE" \
  --gas auto --gas-adjustment 1.4 --gas-prices 1250uhuahua -y
```

Look up a tx result:

```bash
chihuahuad query tx <TXHASH> --node "$NODE" --output json | jq '{code, raw_log}'
```

A `code` of `0` means success; any non-zero code plus `raw_log` tells you why it
failed.

## Multisig accounts

A multisig account requires **K-of-N** members to sign before a transaction broadcasts.
It's the right custody model for anything where one leaked key shouldn't be able to move
funds or change state, and the cases show up all over this skill:

- A **treasury / DAO** account holding HUAHUA or a project token.
- A CosmWasm contract **`--admin`** (so migrations need multiple approvals) — see
  [smart-contracts.md](smart-contracts.md#step-4--instantiate).
- A **tokenfactory denom admin** (so mint/burn isn't one person) — see
  [ecosystem.md](ecosystem.md#native-factory-denom-tokenfactory--recommended).
- A validator **operator account** that collects commission — see
  [node-ops.md](node-ops.md#key--infra-security).

**Friendly path — Keplr Multisig.** [multisig.keplr.app](https://multisig.keplr.app/)
(the Keplr-hosted build of the open-source
[cosmos-multisig-ui](https://github.com/cosmos/cosmos-multisig-ui)) is a web UI:
connect Keplr, "Create New Multisig", enter each member's address/pubkey and the
signature threshold, and it derives the multisig address. From the account page you
"Import Transaction", collect signatures until the threshold is met, then broadcast.
It works for chains the tool has registered — if **Chihuahua (`chihuahua-1`)** isn't
selectable, use the CLI path below (it always works). Note it's a third-party-hosted
web app; for a high-value treasury, prefer the CLI/hardware flow and verify addresses
independently.

**Always-works path — native CLI multisig.** Cosmos SDK has multisig built in. Import
every member's *pubkey* into your keyring first, then:

```bash
# create a 2-of-3 multisig key from members already in your keyring
chihuahuad keys add treasury --multisig=alice,bob,carol --multisig-threshold=2
chihuahuad keys show treasury -a            # the chihuahua1... multisig address

# spend FROM it: 1) build the unsigned tx, 2) each member signs, 3) combine, 4) broadcast
chihuahuad tx bank send $(chihuahuad keys show treasury -a) chihuahua1dest... 5000000uhuahua \
  --chain-id chihuahua-1 --node "$NODE" --generate-only > unsigned.json
chihuahuad tx sign unsigned.json --multisig=$(chihuahuad keys show treasury -a) \
  --from alice --chain-id chihuahua-1 --node "$NODE" > sig-alice.json
chihuahuad tx sign unsigned.json --multisig=$(chihuahuad keys show treasury -a) \
  --from bob   --chain-id chihuahua-1 --node "$NODE" > sig-bob.json
chihuahuad tx multisign unsigned.json treasury sig-alice.json sig-bob.json > signed.json
chihuahuad tx broadcast signed.json --node "$NODE"
```

All members must use the **same** pubkey set and threshold or the derived address won't
match. For richer policies (changing membership without changing the address, weighted
votes), check whether the chain enables the `x/group` module:
`chihuahuad query group group-info 1 --node "$NODE"` (errors if not enabled — then stick
with the legacy multisig above).

## Running a full node

Sync a full node when you need private, rate-limit-free access or you're operating
infrastructure:

```bash
chihuahuad init <moniker> --chain-id chihuahua-1
# fetch the canonical mainnet genesis (from the chain repo)
curl -s https://raw.githubusercontent.com/ChihuahuaChain/chihuahua/main/mainnet/genesis.json \
  -o ~/.chihuahuad/config/genesis.json
# set minimum-gas-prices = "100uhuahua" in app.toml (the chain minimum)
# set seeds / persistent_peers in config.toml: start from the repo's mainnet/seeds.txt
# and mainnet/peers, and replace any that don't answer (the older seed hosts are often
# offline) with live peers taken from a synced node's /net_info
chihuahuad start
```

Seeds and the recommended binary change over time — the authoritative source is the
node guide in the [chihuahua repo](https://github.com/ChihuahuaChain/chihuahua) and
its `mainnet/` directory. Prerequisites for a Ubuntu/Debian box: `make`, `gcc`, `git`,
`jq`, `chrony`, and Go 1.23.9.

For a fast sync, don't run from genesis (slow) — use **state-sync** from a trusted RPC
(e.g. `https://rpc.chihuahua.wtf`: set `[statesync] enable = true`, two `rpc_servers`,
and a recent `trust_height` / `trust_hash` taken from `/block`) or a snapshot from a
validator that publishes one. Remember the `wasm` folder: a CosmWasm chain needs it,
and state-sync fetches it with the snapshot.

> **Fetch these values live, never hardcode them.** Peers, snapshot URLs, and the
> binary version rotate — and providers drop chains without notice (Polkachu, for
> one, no longer serves Chihuahua). Cross-check the
> [repo releases](https://github.com/ChihuahuaChain/chihuahua/releases) and the
> chain's active upgrade proposal on
> [explorer.chihuahua.wtf/proposals](https://explorer.chihuahua.wtf/proposals), and
> run whatever the **current validator set** is on.

## Local devnet (your safe sandbox)

There is no widely-hosted public Chihuahua testnet. For development, deploy contracts
and rehearse transactions against a **single-node local chain** — same binary, throw-
away tokens, instant blocks:

```bash
chihuahuad init devnet --chain-id chihuahua-local
chihuahuad keys add validator
chihuahuad keys add dev
chihuahuad genesis add-genesis-account validator 100000000000000uhuahua
chihuahuad genesis add-genesis-account dev       100000000000000uhuahua
chihuahuad genesis gentx validator 1000000000000uhuahua --chain-id chihuahua-local
chihuahuad genesis collect-gentxs
chihuahuad start
```

(On older binaries the subcommands are `add-genesis-account`/`gentx`/`collect-gentxs`
without the `genesis` prefix.) Now `--chain-id chihuahua-local --node http://localhost:26657`
gives you a permissionless CosmWasm playground where `store-code` always works,
letting you validate the full contract lifecycle before touching mainnet.
