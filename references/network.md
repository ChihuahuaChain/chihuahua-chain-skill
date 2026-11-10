# Chihuahua Network Reference

Everything about connecting to `chihuahua-1`: versions, endpoints, denoms, gas and
fees, the CLI, the testnet and running a node. Facts were checked live on 2026-11-10.
The cosmos chain-registry (`chihuahua/chain.json`) still lists several providers that
have since dropped the chain. Endpoints rotate: if one is down, move to the next, and
prefer the `chihuahua.wtf` ones.

## Table of contents

- [Chain identity](#chain-identity)
- [Versions and recent upgrades](#versions-and-recent-upgrades)
- [Chain economics](#chain-economics)
- [Denominations & gas](#denominations--gas)
- [Fee burn and the burn address](#fee-burn-and-the-burn-address)
- [RPC endpoints](#rpc-endpoints)
- [REST / LCD endpoints](#rest--lcd-endpoints)
- [gRPC endpoints](#grpc-endpoints)
- [WebSocket (events & subscriptions)](#websocket-events--subscriptions)
- [Explorers](#explorers)
- [IBC status](#ibc-status)
- [The chihuahuad CLI](#the-chihuahuad-cli)
- [Common CLI recipes](#common-cli-recipes)
- [Multisig accounts](#multisig-accounts)
- [Running a full node](#running-a-full-node)
- [Testnet: woofnet-6](#testnet-woofnet-6)
- [Local devnet](#local-devnet)

## Chain identity

| Field | Value |
|-------|-------|
| Chain ID | `chihuahua-1` |
| Bech32 prefix | `chihuahua` (account), `chihuahuavaloper` (validator), `chihuahuavalcons` (consensus) |
| SLIP-44 coin type | `118` |
| Daemon | `chihuahuad` |
| Node home | `$HOME/.chihuahuad` |
| Source | https://github.com/ChihuahuaChain/chihuahua |
| Current binary | `v10.0.1`: Cosmos SDK v0.54.4, CometBFT v0.39.4, ibc-go v11.2, wasmd v0.70.4 / wasmvm v3, Go 1.26.5 |

> Always confirm the latest [release](https://github.com/ChihuahuaChain/chihuahua/releases)
> and any upgrade proposal in voting on
> [explorer.chihuahua.wtf/proposals](https://explorer.chihuahua.wtf/proposals) before
> syncing a node. The live version is reported by
> `curl -s https://api.chihuahua.wtf/cosmos/base/tendermint/v1beta1/node_info | jq .application_version.version`.

## Versions and recent upgrades

| Version | Proposal | Height | What changed |
|---------|----------|--------|--------------|
| v9.0.7 |  | until 25,571,500 | Cosmos SDK v0.50 |
| v9.5.0 | #100 | 25,571,500 (2026-10-02) | Retired the Alliance module (#99): its HUAHUA went back to the ecosystem fund, staked ampGASH and unclaimed rewards were burned. `fee_payer` event attribute is bech32 again, which unblocked the Hermes relayer. |
| v10.0.0 | #101 | 25,586,332 (2026-10-03) | Cosmos SDK v0.54.4, CometBFT v0.39.4, ibc-go v11, wasmd v0.70 / wasmvm v3. Removed modules: alliance, nft, circuit, crisis, capability, ICS-29 fee, x/params. `x/liquidity` maintained in-house; `x/group` kept. On-chain counter of burned fees. |
| v10.0.1 | #106 | 25,742,780 (2026-10-14) | **Minimum gas price in consensus** (x/feeburn `min_gas_prices`, set to 500 uhuahua). The x/feeburn module account becomes the public burn address. Max contract size 1600 KiB (was 800). Atomic, fail-safe liquidity batches. Upgrade and consensus hardening. |

What these mean for code written before October 2026:

- **CosmJS must be >= 0.39.** Account numbers on SDK v0.54 can exceed 2^53 (a fresh
  testnet account had number 13945776506362939809); older CosmJS cannot represent
  them and fails to sign.
- **CometBFT v0.39 RPC.** CosmJS 0.39 works against it: `StargateClient`,
  `CosmWasmClient`, `SigningStargateClient` (simulate and broadcast) and
  `connectComet` were tested against v10.0.1. Use `connectComet` or `Comet38Client`
  rather than `Tendermint37Client`. CosmJS WebSocket subscriptions, however, receive
  no events from CometBFT v0.39: use a plain WebSocket for those. The REST API is an equally good path for
  simulate (`POST /cosmos/tx/v1beta1/simulate`) and broadcast
  (`POST /cosmos/tx/v1beta1/txs`), and it is what the chain's own dApps use.
- **No `x/params` or `x/crisis`** queries; the DenomTrace stargate query is gone
  (use `/ibc/apps/transfer/v1/denoms/{hash}`).

## Chain economics

| Fact | Value | Source |
|------|-------|--------|
| Inflation | **0%** | proposal #97; `GET /cosmos/mint/v1beta1/inflation` |
| Active validator set | **30** seats, min commission 5%, unbonding 21 days | proposal #103; `GET /cosmos/staking/v1beta1/params` |
| Governance deposit | **50,000,000 HUAHUA** (expedited 200,000,000), 25% upfront, 5-day deposit and voting periods | proposal #107; `GET /cosmos/gov/v1/params/deposit` |
| Community pool | emptied and burned | proposal #105 |
| Fee burn | **50%** of every transaction fee | `GET /chihuahua/feeburn/params` (`txFeeBurnPercent`) |
| Total supply | ~114.37 billion HUAHUA (2026-11-10) | `GET /cosmos/bank/v1beta1/supply/by_denom?denom=uhuahua` |

## Denominations & gas

- **Base denom:** `uhuahua`: this is what every on-chain amount uses.
- **Display denom:** `huahua`, exponent 6. `1 HUAHUA = 1_000_000 uhuahua`.
- **Symbol:** HUAHUA.

**Gas price.** Since v10.0.1 the chain enforces a minimum gas price **in
consensus**: x/feeburn `min_gas_prices`, **500 uhuahua per gas**, set by governance.
A transaction paying less is rejected by every node, whatever that node's local
`minimum-gas-prices` in `app.toml` says. Read the live value instead of trusting a
constant:

```bash
curl -s https://api.chihuahua.wtf/chihuahua/feeburn/params
# {"params":{"txFeeBurnPercent":"50","min_gas_prices":[{"denom":"uhuahua","amount":"500.000000000000000000"}]}}
```

| Tier (wallets) | Price |
|----------------|-------|
| Low = consensus minimum | `500uhuahua` |
| Average | `750uhuahua` |
| High | `1000uhuahua` |

Never fall back to the generic Cosmos `0.025`: it is 20,000x below the floor and is
rejected as `insufficient fee`. The older `100uhuahua` minimum no longer applies.

**Gas limit.** Simulations underestimate on this chain: in one measured send the
transaction used 73,202 gas against a simulated 51,775 (+41%), so CosmJS's default
`"auto"` (simulation × 1.4) ran out of gas. A transaction that runs out of gas **still
pays its fee** and changes nothing. Pad generously:

```bash
--gas auto --gas-adjustment 1.6 --gas-prices 500uhuahua
```

In code, use simulation × 1.6 + 30,000 (see [dapp-dev.md](dapp-dev.md#gas-and-fees)).
Governance votes are the exception: pass a fixed `--gas 200000`, since `auto`
underestimates them.

The fee is the gas **limit** times the price, so padding costs a little. What things
cost at 500 uhuahua per gas (measured): a bank send ~40 to 60 HUAHUA, a contract
execution ~130 to 250 HUAHUA, storing a ~400 KB contract ~1,400 to 4,200 HUAHUA
depending on compression and padding (see
[smart-contracts.md](smart-contracts.md#step-3-store-the-code)).

## Fee burn and the burn address

- **Half of every transaction fee is burned** in the ante handler
  (`txFeeBurnPercent: 50`). The running total is on chain:

  ```bash
  curl -s https://api.chihuahua.wtf/chihuahua/feeburn/total_burned
  # {"total_burned":[{"denom":"uhuahua","amount":"..."}]}
  chihuahuad query feeburn total-burned --node "$NODE"
  ```

  Don't count burns from logs: the ante handler also runs in simulations and block
  proposals, so a log line can appear several times per transaction.

- **Public burn address:** the x/feeburn module account
  `chihuahua1d99pujdz48wkmn3uesfxnrctn44uuf5cuw5xuu`. HUAHUA and tokenfactory denoms
  sent there (a plain `bank send`, a community-pool spend, or a contract's
  `BankMsg::Send`) are **burned at the end of the block** and added to the on-chain
  total. IBC vouchers and other denoms sent there are left untouched, so a burn
  never strands an escrowed asset. The public figure is shown on
  [burn.chihuahua.wtf](https://burn.chihuahua.wtf).

## RPC endpoints

CometBFT RPC (for `--node`, status, blocks, tx broadcast):

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

Cosmos SDK REST API (HTTP/JSON queries, simulate and broadcast; CORS open on the
chain's own endpoint):

```
https://api.chihuahua.wtf
https://chihuahua-api.kleomedes.network
```

Example: query a balance over REST:

```bash
curl -s "https://api.chihuahua.wtf/cosmos/bank/v1beta1/balances/chihuahua1youraddresshere" | jq
```

## gRPC endpoints

For `grpc`/protobuf clients and high-throughput indexing (CosmJS does not need gRPC).
The chain's own endpoint is served over TLS on port 443; most third-party providers
in the chain-registry no longer serve gRPC, so the second one is a fallback. Run your
own node (`:9090`) for anything serious:

```
grpc.chihuahua.wtf:443                # primary
grpc.chihuahua.validatus.com:443      # fallback
```

Example: latest block with [grpcurl](https://github.com/fullstorydev/grpcurl):

```bash
grpcurl grpc.chihuahua.wtf:443 cosmos.base.tendermint.v1beta1.Service/GetLatestBlock
```

## WebSocket (events & subscriptions)

CometBFT exposes JSON-RPC over WebSocket at `/websocket` on every RPC node. There is
no separate WS host: append `/websocket` to an RPC URL and switch the scheme to
`wss://`:

```
wss://rpc.chihuahua.wtf/websocket
```

(In a 2026-11-10 test, `rpc.chihuahua.wtf` delivered events; other providers
accepted the subscription but sent nothing. Test a fallback before relying on it.)

Subscribe to new blocks (raw protocol; most clients wrap this for you):

```json
{
  "jsonrpc": "2.0",
  "method": "subscribe",
  "id": 1,
  "params": { "query": "tm.event='NewBlock'" }
}
```

Other useful queries: `tm.event='Tx'` (every tx), or filter by an event attribute,
e.g. `tm.event='Tx' AND transfer.recipient='chihuahua1...'` to watch deposits to an
address. See [dapp-dev.md](dapp-dev.md#live-updates-over-websocket) for code: CosmJS
0.39's own subscriptions receive nothing from CometBFT v0.39, so use a plain
WebSocket.
Subscriptions are best-effort and can drop under load: for guaranteed delivery, poll
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

Two things it doesn't have a page for, and the CLI answers directly:

```bash
# code IDs and the contracts instantiated from one (resolve a *current* address)
chihuahuad query wasm list-code --node "$NODE"
chihuahuad query wasm list-contract-by-code <CODE_ID> --node "$NODE"
# IBC channels (channel IDs, counterparty, state) before standing up a relayer
chihuahuad query ibc channel channels --node "$NODE" --output json \
  | jq '.channels[] | {channel_id, state, counterparty}'
```

## IBC status

As of 2026-11-10 the only live IBC path is **Chihuahua `channel-7` ↔ Osmosis
`channel-113`** (light client `07-tendermint-45`, recovered by proposal #102). Most
of the chain's other ~200 channels still show `STATE_OPEN`, but their light clients
have **expired**, so transfers over them fail. Check a client before relying on a
channel:

```bash
curl -s https://api.chihuahua.wtf/ibc/core/client/v1/client_status/07-tendermint-45   # {"status":"Active"}
```

Assets from other chains reach Chihuahua **through Osmosis**. The USDC used on
Chihuahua is Injective's USDC routed via Osmosis:
`ibc/2CAD00F0570FC6068204B0F4DB49B5752ABEC73B8604693C528B0D9A4417A4D1`. Noble USDC is
being wound down by Circle. See [skip-go.md](skip-go.md) for routing.

## The chihuahuad CLI

On Linux, download the static `chihuahuad_linux_amd64` or `chihuahuad_linux_arm64`
binary from the [release page](https://github.com/ChihuahuaChain/chihuahua/releases)
and check it against the published sha256. Elsewhere (e.g. macOS), build from source:
`v10.0.1` needs **Go 1.26.5** (confirm against `go.mod` of the tag you check out).
[`scripts/install-chihuahuad.sh`](../scripts/install-chihuahuad.sh) does this:

```bash
git clone https://github.com/ChihuahuaChain/chihuahua
cd chihuahua
git fetch --tags
git checkout v10.0.1    # latest release; or the current consensus version
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
these and gives you a `huahua` wrapper that injects the node flag automatically.

## Common CLI recipes

Keys (try the workflow on the testnet first: on mainnet these manage real funds):

```bash
chihuahuad keys add mykey                       # create
chihuahuad keys add mykey --recover             # import from mnemonic
chihuahuad keys show mykey -a                   # print chihuahua1... address
chihuahuad keys list
```

Query balance:

```bash
chihuahuad query bank balances chihuahua1... --node "$NODE"
```

Send HUAHUA (amount is in uhuahua: 5 HUAHUA = 5000000uhuahua):

```bash
chihuahuad tx bank send mykey chihuahua1recipient... 5000000uhuahua \
  --chain-id chihuahua-1 --node "$NODE" \
  --gas auto --gas-adjustment 1.6 --gas-prices 500uhuahua -y
```

Look up a tx result:

```bash
chihuahuad query tx <TXHASH> --node "$NODE" --output json | jq '{code, raw_log}'
```

A `code` of `0` means success; any non-zero code plus `raw_log` tells you why it
failed. Code `11` is out of gas (the fee was still paid: raise `--gas-adjustment`);
code `13` is insufficient fee (pay at least the 500 uhuahua minimum).

## Multisig accounts

A multisig account requires **K-of-N** members to sign before a transaction
broadcasts. It's the right custody model wherever one leaked key shouldn't be able to
move funds or change state:

- A **treasury / DAO** account holding HUAHUA or a project token.
- A CosmWasm contract **`--admin`** (so migrations need multiple approvals); see
  [smart-contracts.md](smart-contracts.md#step-4-instantiate).
- A **tokenfactory denom admin** (so mint, burn and force-transfer aren't one person);
  see [ecosystem.md](ecosystem.md#native-factory-denom-tokenfactory).
- A validator **operator account** that collects commission; see
  [node-ops.md](node-ops.md#key--infra-security).

**Friendly path: Keplr Multisig.** [multisig.keplr.app](https://multisig.keplr.app/)
(the Keplr-hosted build of the open-source
[cosmos-multisig-ui](https://github.com/cosmos/cosmos-multisig-ui)) is a web UI:
connect Keplr, "Create New Multisig", enter each member's address/pubkey and the
signature threshold, and it derives the multisig address. From the account page you
"Import Transaction", collect signatures until the threshold is met, then broadcast.
If **Chihuahua (`chihuahua-1`)** isn't selectable, use the CLI path below. It is a
third-party web app: for a high-value treasury, prefer the CLI/hardware flow and
verify addresses independently.

**Always-works path: native CLI multisig.** Import every member's _pubkey_ into your
keyring first, then:

```bash
# create a 2-of-3 multisig key from members already in your keyring
chihuahuad keys add treasury --multisig=alice,bob,carol --multisig-threshold=2
chihuahuad keys show treasury -a            # the chihuahua1... multisig address

# spend FROM it: 1) build the unsigned tx, 2) each member signs, 3) combine, 4) broadcast
chihuahuad tx bank send $(chihuahuad keys show treasury -a) chihuahua1dest... 5000000uhuahua \
  --chain-id chihuahua-1 --node "$NODE" --gas 200000 --fees 100000000uhuahua --generate-only > unsigned.json
chihuahuad tx sign unsigned.json --multisig=$(chihuahuad keys show treasury -a) \
  --from alice --chain-id chihuahua-1 --node "$NODE" > sig-alice.json
chihuahuad tx sign unsigned.json --multisig=$(chihuahuad keys show treasury -a) \
  --from bob   --chain-id chihuahua-1 --node "$NODE" > sig-bob.json
chihuahuad tx multisign unsigned.json treasury sig-alice.json sig-bob.json > signed.json
chihuahuad tx broadcast signed.json --node "$NODE"
```

(A `--generate-only` tx cannot simulate, so set the gas and a fee of at least
gas × 500 uhuahua yourself.) All members must use the **same** pubkey set and
threshold or the derived address won't match. `x/group` is available on Chihuahua for
richer policies (membership changes without changing the address, weighted votes).

## Running a full node

The quickest path is the **[Huahua Node Manager](https://github.com/ChihuahuaChain/huahua-node-manager)**:
one command sets up a synced node under cosmovisor and systemd (or Docker) and opens
a live dashboard. See [node-ops.md](node-ops.md#huahua-node-manager-the-quick-path).

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/ChihuahuaChain/huahua-node-manager/main/huahua-node.sh)
```

Manual path:

```bash
chihuahuad init <moniker> --chain-id chihuahua-1
curl -s https://raw.githubusercontent.com/ChihuahuaChain/chihuahua/main/mainnet/genesis.json \
  -o ~/.chihuahuad/config/genesis.json
# app.toml: minimum-gas-prices = "500uhuahua" (the consensus floor)
# config.toml: seeds / persistent_peers from the repo's mainnet/ directory, replacing
# any that don't answer with live peers from a synced node's /net_info
chihuahuad start
```

Don't sync from genesis (slow). Either:

- **Snapshot:** pruned snapshots of `chihuahua-1` are published twice a day at
  [snapshots.chihuahua.wtf](https://snapshots.chihuahua.wtf)
  (`chihuahua_latest.tar.lz4`, `latest.json` with the height). Extract it into the
  node home (it includes the `wasm` folder) and start.
- **State sync** from a trusted RPC (e.g. `https://rpc.chihuahua.wtf`): set
  `[statesync] enable = true`, two `rpc_servers`, and a recent `trust_height` /
  `trust_hash` taken from `/block`.

Prerequisites on Ubuntu/Debian: `curl`, `jq`, `lz4`, `chrony`; plus `make`, `gcc`,
`git` and Go 1.26.5 if you build from source.

> **Fetch peers, snapshots and the binary version live, never hardcode them.** Cross-
> check the [repo releases](https://github.com/ChihuahuaChain/chihuahua/releases) and
> any upgrade proposal on
> [explorer.chihuahua.wtf/proposals](https://explorer.chihuahua.wtf/proposals), and
> run whatever the **current validator set** is on.

## Testnet: woofnet-6

A public testnet, started 2026-09-27 and upgraded to the mainnet binary (v10.0.1).
Use it for every first deploy and rehearsal:

| Field | Value |
|-------|-------|
| Chain ID | `woofnet-6` |
| RPC | `https://testnet-rpc.chihuahua.wtf` |
| REST | `https://testnet-api.chihuahua.wtf` |
| Faucet | `https://testnet-faucet.chihuahua.wtf`: 10,000,000 test HUAHUA + 100 test USDC per request |
| Add to Keplr | https://keplr.chihuahua.wtf/testnet.html |
| Blocks | ~2 s, single validator |
| Governance | 10-minute voting, 1,000 HUAHUA deposit |
| Wasm upload | open to everybody |
| Gas | the same 500 uhuahua consensus minimum as mainnet |

Claim from the faucet programmatically:

```bash
curl -s -X POST https://testnet-faucet.chihuahua.wtf/api/claim \
  -H 'content-type: application/json' -d '{"address":"chihuahua1..."}'
# {"txhash":"...","amount":"10000000000000uhuahua,100000000ibc/..."}
```

Test USDC uses the same `ibc/...` denom as mainnet USDC, so a dApp's config works
unchanged across the two networks. Only RPC, REST and the faucet are public (no gRPC).

## Local devnet

For instant blocks and full control (e.g. testing an upgrade or a genesis change),
run a single-node chain on your machine with the same binary:

```bash
chihuahuad init devnet --chain-id chihuahua-local
chihuahuad keys add validator --keyring-backend test
chihuahuad keys add dev --keyring-backend test
chihuahuad genesis add-genesis-account validator 100000000000000uhuahua --keyring-backend test
chihuahuad genesis add-genesis-account dev       100000000000000uhuahua --keyring-backend test
chihuahuad genesis gentx validator 1000000000000uhuahua --chain-id chihuahua-local --keyring-backend test
chihuahuad genesis collect-gentxs
chihuahuad start
```

Then `--chain-id chihuahua-local --node http://localhost:26657` gives you a
permissionless CosmWasm playground. The consensus gas floor comes from x/feeburn's
genesis params: set `min_gas_prices` there to match mainnet (500uhuahua) so fees
behave the same.
