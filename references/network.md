# Chihuahua Network Reference

Everything about connecting to `chihuahua-1`: endpoints, denoms, gas, the CLI, and
running a node. Data sourced from the cosmos chain-registry
(`chihuahua/chain.json`, `chihuahua/assetlist.json`). Endpoints are operated by
independent validators and rotate often — if one is down, move to the next.

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
https://chihuahua-rpc.polkachu.com
https://chihuahua-rpc.publicnode.com:443
https://rpc.lavenderfive.com:443/chihuahua
https://chihuahua-rpc.chainroot.io
https://rpc-chihuahua-ia.cosmosia.notional.ventures
https://chihuahua-mainnet-rpc.autostake.com:443
https://rpc.huahua.bh.rocks
https://chihuahua-rpc.kleomedes.network
https://rpc.chihuahua.validatus.com
https://chihuahua.rpc.nodeshub.online:443
https://chihua.rpc.m.stavr.tech
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
https://chihuahua-api.polkachu.com
https://chihuahua-rest.publicnode.com
https://rest.lavenderfive.com:443/chihuahua
https://chihuahua-api.chainroot.io
https://api-chihuahua-ia.cosmosia.notional.ventures
https://chihuahua-mainnet-lcd.autostake.com:443
https://chihuahua-api.kleomedes.network
https://api.chihuahua.validatus.com
https://chihuahua.api.nodeshub.online:443
https://chihua.api.m.stavr.tech
```

Example — query a balance over REST:

```bash
curl -s "https://api.chihuahua.wtf/cosmos/bank/v1beta1/balances/chihuahua1youraddresshere" | jq
```

## gRPC endpoints

For CosmJS/`grpc`/protobuf clients and high-throughput indexing:

```
chihuahua-grpc.polkachu.com:12990
chihuahua.lavenderfive.com:443
grpc-chihuahua-ia.cosmosia.notional.ventures:443
chihuahua-grpc.publicnode.com:443
chihuahua-mainnet-grpc.autostake.com:443
grpc-chihuahua.cosmos-spaces.cloud:2290
grpc.chihuahua.validatus.com:443
chihuahua.grpc.nodeshub.online
chihuahua-grpc.chainroot.io:443
chihua.grpc.m.stavr.tech:108
```

## WebSocket (events & subscriptions)

CometBFT exposes a JSON-RPC-over-WebSocket endpoint at `/websocket` on every RPC
node. There is no separate WS host — append `/websocket` to an RPC URL and switch
the scheme to `wss://`:

```
wss://rpc.chihuahua.wtf/websocket
wss://chihuahua-rpc.publicnode.com:443/websocket
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
https://www.mintscan.io/chihuahua
https://ping.pub/chihuahua
https://atomscan.com/chihuahua
https://explorer.stavr.tech/Chihua-Mainnet
https://staking-explorer.com/explorer/chihuahua
https://ezstaking.app/chihuahua
https://explorer.nodeshub.online/chihuahua/
```

Use an explorer to confirm a tx hash landed (`/txs/<HASH>` or the search box) and to
read a contract's address, code ID, and instantiation history.

[Mintscan](https://www.mintscan.io/chihuahua) is the most feature-complete and the one
to reach for when a *build* task needs on-chain facts a human has to look up by eye:

- **CosmWasm tab** — browse deployed code IDs and contract addresses. This is the
  fastest way to resolve the *current* address of an ecosystem contract (Huahuaswap
  pools, a token, an NFT collection) instead of trusting a stale value from a tutorial.
- **IBC tab** — see which channels already exist between Chihuahua and another chain
  (channel IDs, client/connection, relayer status). Check this before standing up a
  relayer, and use it to resolve which `ibc/<HASH>` voucher a transferred asset became.
- **Proposals tab** — track upgrade proposals (the version + height your node must be
  on) and any wasm-permission governance.

It's a human-facing surface — the agent can't click it, but it's where you (or a
teammate) look up a code ID, contract address, or channel ID to hand to the agent.

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
# set seeds in config.toml:
#   77cbb35d1df17f48a42e9f157f12f55b691e9f5e@seeds.goldenratiostaking.net:1620
#   4936e377b4d4f17048f8961838a5035a4d21240c@chihuahua-seed-01.mercury-nodes.net:29540
# (persistent_peers are listed in the repo's mainnet docs — confirm current ones there)
chihuahuad start
```

Seeds and the recommended binary change over time — the authoritative source is the
node guide in the [chihuahua repo](https://github.com/ChihuahuaChain/chihuahua) and
its `mainnet/` directory. Prerequisites for a Ubuntu/Debian box: `make`, `gcc`, `git`,
`jq`, `chrony`, and Go 1.23.9.

For a fast sync, don't run from genesis (slow) — use a **state-sync** or a **snapshot**.
[Polkachu](https://polkachu.com/networks/chihuahua) maintains the most complete,
auto-updated set of Chihuahua node resources, each on its own page:

- [Installation guide](https://polkachu.com/installation/chihuahua) — Cosmovisor-based, with the version it currently tracks
- [Snapshot](https://polkachu.com/tendermint_snapshots/chihuahua) — lz4-streamed, includes the `wasm` subfolder (needed for a CosmWasm chain)
- [State-sync](https://polkachu.com/state_sync/chihuahua) — node syncing in ~10 minutes
- [Live peers](https://polkachu.com/live_peers/chihuahua) / [addrbook](https://polkachu.com/addrbooks/chihuahua) / seeds — auto-updated
- [Chain-upgrades tracker](https://polkachu.com/chain_upgrades) — upcoming upgrade names + heights

> **These are exactly the values you fetch live, never hardcode.** Peers, addrbook,
> snapshot URLs, and the tracked binary version rotate constantly — that's the whole
> point of pointing at a maintained provider instead of pasting a peer into the skill.
> One catch worth noting: providers can lag each other on the version (e.g. Polkachu's
> installer may track `v9.0.6` while the repo's latest release is `v9.0.7`). Cross-check
> the [repo releases](https://github.com/ChihuahuaChain/chihuahua/releases) and the
> chain's active upgrade proposal, and run whatever the **current validator set** is on.
> Lavender.Five and AutoStake publish equivalent snapshots if you want an alternative.

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
