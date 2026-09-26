# Operating Chihuahua Infrastructure: Validators & Relayers

This is the **operator** path, distinct from app development. Read it if you're
running infrastructure: becoming a validator that produces blocks, or running an IBC
relayer that moves packets between Chihuahua and another chain. Both assume you can
already sync a full node — see
[network.md → Running a full node](network.md#running-a-full-node) first.

- [Becoming a validator](#becoming-a-validator)
- [Safe upgrades with Cosmovisor](#safe-upgrades-with-cosmovisor)
- [Key & infra security](#key--infra-security)
- [Running an IBC relayer (Hermes)](#running-an-ibc-relayer-hermes)

> Validating mainnet is real responsibility: downtime gets you slashed for
> liveness, and a double-sign (usually from running two nodes on the same key) gets
> you **tombstoned** — permanently removed. Rehearse on the
> [local devnet](network.md#local-devnet-your-safe-sandbox) and treat the consensus
> key as the most dangerous secret you hold.

## Becoming a validator

You need a **fully synced** node (`catching_up: false`) and an account funded with
HUAHUA to self-delegate. To get synced in minutes rather than from genesis, use
state-sync or a validator's snapshot (see
[network.md → fast sync](network.md#running-a-full-node)). Then submit a
`create-validator` tx. Modern Cosmos SDK takes a JSON file:

```bash
# 1. grab your node's consensus pubkey
chihuahuad tendermint show-validator     # -> {"@type":"/cosmos.crypto.ed25519.PubKey","key":"..."}

# 2. write validator.json
cat > validator.json <<'JSON'
{
  "pubkey": {"@type":"/cosmos.crypto.ed25519.PubKey","key":"<FROM_STEP_1>"},
  "amount": "1000000000uhuahua",
  "moniker": "<your-moniker>",
  "identity": "",
  "website": "",
  "security": "",
  "details": "",
  "commission-rate": "0.05",
  "commission-max-rate": "0.20",
  "commission-max-change-rate": "0.01",
  "min-self-delegation": "1"
}
JSON

# 3. broadcast it
chihuahuad tx staking create-validator validator.json --from "$KEY" $TXFLAGS
```

(On older binaries, `create-validator` takes individual `--amount`, `--pubkey`,
`--moniker`, `--commission-rate` flags instead of a JSON file — check
`chihuahuad tx staking create-validator --help`.) `$TXFLAGS`/`$KEY` come from
[scripts/chihuahua-env.sh](../scripts/chihuahua-env.sh). Confirm you're in the active
set with `chihuahuad query staking validator $(chihuahuad keys show $KEY --bech val -a)`.

## Safe upgrades with Cosmovisor

Chihuahua coordinates chain upgrades through governance (a new binary version at a
target height). If your node is on the wrong binary at the upgrade height, it halts.
**Cosmovisor** automates the swap so you don't have to babysit a 3am upgrade:

```bash
go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@latest
export DAEMON_NAME=chihuahuad
export DAEMON_HOME=$HOME/.chihuahuad
mkdir -p $DAEMON_HOME/cosmovisor/genesis/bin
cp $(which chihuahuad) $DAEMON_HOME/cosmovisor/genesis/bin/
# pre-stage the upgrade binary so cosmovisor switches automatically at the height:
#   $DAEMON_HOME/cosmovisor/upgrades/<upgrade-name>/bin/chihuahuad
cosmovisor run start        # run this under systemd instead of `chihuahuad start`
```

Watch for upgrades via the chain's governance proposals on
[explorer.chihuahua.wtf/proposals](https://explorer.chihuahua.wtf/proposals) (or any
explorer in [network.md](network.md#explorers)): a software-upgrade proposal carries
the upgrade name and target height. Pre-stage the matching binary built
from the [right release](https://github.com/ChihuahuaChain/chihuahua/releases) (the
chain is on **v9.0.7** as of this writing; coordinated version bumps like this are
exactly what Cosmovisor handles). Set
`DAEMON_ALLOW_DOWNLOAD_BINARIES=false` in production — auto-downloading an upgrade
binary is a supply-chain risk; build and stage it yourself.

## Key & infra security

- **One consensus key, one running node. Ever.** Two nodes signing with the same key
  = double-sign = tombstoned. Don't "warm up" a backup by starting it.
- **Use a sentry or remote signer for the consensus key.** TMKMS (a remote signer
  with HSM support) keeps the priv-validator key off the public node and enforces
  double-sign protection independently.
- **The operator account key** (the `$KEY` that holds funds and collects commission)
  is separate from the consensus key — keep it in a hardware wallet, not on the
  server. For a team-run validator, make the operator account a **multisig** so no
  single member can move the self-bond or commission alone — see
  [network.md → Multisig accounts](network.md#multisig-accounts).
- Back up `priv_validator_key.json` and your mnemonic offline; losing the operator
  key loses your commission and self-bond control.

## Running an IBC relayer (Hermes)

A relayer watches two chains and delivers IBC packets between them (transfers,
acks, timeouts). **Most app developers don't need to run one** — the major Chihuahua
channels (to Osmosis, the Hub, etc.) are already relayed by others, and your IBC
transfers ride those. Run your own only if you're launching a new channel, need
guaranteed liveness for your app's specific path, or want to support the network.

[Hermes](https://hermes.informal.systems) is the standard relayer. Add Chihuahua to
its `config.toml` as a chain entry:

```toml
[[chains]]
id = 'chihuahua-1'
rpc_addr = 'https://rpc.chihuahua.wtf'
grpc_addr = 'https://grpc.chihuahua.validatus.com:443'   # or your own node's :9090
event_source = { mode = 'push', url = 'wss://rpc.chihuahua.wtf/websocket', batch_delay = '500ms' }
account_prefix = 'chihuahua'
key_name = 'relayer'
store_prefix = 'ibc'
gas_price = { price = 1250, denom = 'uhuahua' }   # match the chain's gas tier
gas_multiplier = 1.4
max_gas = 4000000
trusting_period = '14days'
```

Then fund a `relayer` key with HUAHUA on Chihuahua (and the native token on the
counterparty chain — a relayer pays gas on **both** ends), import it
(`hermes keys add --chain chihuahua-1 --mnemonic-file ...`), and either relay an
existing channel or create a new connection/channel.

> **Check for an existing channel first.** Most major paths (Chihuahua ↔ Osmosis,
> ↔ the Hub) already have a canonical channel — relaying that one is far cheaper than
> creating a duplicate that fragments liquidity. Look up the live channel IDs
> (`chihuahuad query ibc channel channels`, see
> [network.md](network.md#explorers)) before running `create channel`, and prefer
> relaying the established channel.

```bash
hermes health-check
hermes start                                   # relay all configured paths
# or stand up a brand new path:
hermes create channel --a-chain chihuahua-1 --b-chain <other-1> \
  --a-port transfer --b-port transfer --new-client-connection
```

Keep the relayer key funded on every chain it serves — a relayer that runs out of gas
silently stops delivering packets, which looks like "my IBC transfers are stuck."
Monitor balances and set alerts.
