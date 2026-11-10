# Operating Chihuahua Infrastructure: Nodes, Validators & Relayers

This is the **operator** path, distinct from app development: running a node, becoming
a validator, following upgrades, or running an IBC relayer.

- [Huahua Node Manager (the quick path)](#huahua-node-manager-the-quick-path)
- [Becoming a validator](#becoming-a-validator)
- [Upgrades with cosmovisor](#upgrades-with-cosmovisor)
- [Key & infra security](#key--infra-security)
- [Running an IBC relayer](#running-an-ibc-relayer)

> Validating mainnet is real responsibility: downtime gets you slashed for liveness,
> and a double-sign (usually from running two nodes on the same key) gets you
> **tombstoned**, permanently removed. Rehearse on the
> [woofnet-6 testnet](network.md#testnet-woofnet-6) and treat the consensus key as the
> most dangerous secret you hold.

## Huahua Node Manager (the quick path)

[Huahua Node Manager](https://github.com/ChihuahuaChain/huahua-node-manager) sets up
and manages a `chihuahua-1` node from one command (Linux, amd64 and arm64):

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/ChihuahuaChain/huahua-node-manager/main/huahua-node.sh)
```

To read the script first: `curl -fsSLO .../huahua-node.sh && less huahua-node.sh && bash huahua-node.sh`.
Choose **Easy**, answer three questions, and a few minutes later the node is synced,
running under cosmovisor and started at boot. What it does:

- **Fast sync** from the latest snapshot at
  [snapshots.chihuahua.wtf](https://snapshots.chihuahua.wtf) (refreshed every 12
  hours), or by state sync.
- **Verified downloads:** the `chihuahuad` release, cosmovisor and the genesis are
  checked against their sha256.
- **Automatic upgrades:** an hourly check stages the upgrade scheduled by governance,
  and cosmovisor switches the binary at the upgrade height.
- **systemd or Docker**, peers and free ports found for you, P2P port opened and
  checked from the internet, `minimum-gas-prices` set to `500uhuahua`.
- **Existing nodes** on the machine are found and can be moved under cosmovisor.
- **Validators:** a guided `create-validator`, from the key to the broadcast; it always
  asks before sending.
- **Live dashboard** (`huahua-node`): node, sync, logs, upgrades (scheduled upgrade,
  proposals in voting, a live consensus view), validator state (active, jailed,
  missed blocks), setup.

Useful commands:

```sh
huahua-node                        # the dashboard
huahua-node upgrade                # stage the scheduled upgrade now (or one still in voting)
huahua-node auto-upgrade on|off|status
```

The rest of this page is the manual path, for when you want to know what it does or
run something it doesn't cover.

## Becoming a validator

You need a **fully synced** node (`catching_up: false`) and an account funded with
HUAHUA to self-delegate. The active set has **30 seats** (proposal #103), the minimum
commission is **5%**, unbonding takes 21 days. Submit a `create-validator` tx with a
JSON file:

```bash
# 1. your node's consensus pubkey
chihuahuad comet show-validator     # -> {"@type":"/cosmos.crypto.ed25519.PubKey","key":"..."}

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

(`chihuahuad tendermint show-validator` is the older name of step 1.) `$TXFLAGS`/`$KEY`
come from [scripts/chihuahua-env.sh](../scripts/chihuahua-env.sh). Check your place in
the set with
`chihuahuad query staking validator $(chihuahuad keys show $KEY --bech val -a)`: only
the top 30 by stake sign blocks and earn.

Point the node's own CLI at itself (`node = "tcp://localhost:26657"` in
`~/.chihuahuad/config/client.toml`). Vote on governance with a fixed
`--gas 200000`: `--gas auto` underestimates votes.

## Upgrades with cosmovisor

Chihuahua coordinates upgrades through governance: a software-upgrade proposal names
the plan and the target height (recent ones: v9.5.0 #100, v10.0.0 #101, v10.0.1 #106;
the chain is on **v10.0.1**). A node on the wrong binary at the upgrade height halts.
**Cosmovisor** swaps the binary at that height:

```bash
go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@latest
export DAEMON_NAME=chihuahuad
export DAEMON_HOME=$HOME/.chihuahuad
export DAEMON_SHUTDOWN_GRACE=30s   # let the node flush cleanly before the swap
mkdir -p $DAEMON_HOME/cosmovisor/genesis/bin
cp $(which chihuahuad) $DAEMON_HOME/cosmovisor/genesis/bin/
# pre-stage the upgrade binary so cosmovisor switches at the height:
#   $DAEMON_HOME/cosmovisor/upgrades/<plan-name>/bin/chihuahuad
cosmovisor run start        # run this under systemd instead of `chihuahuad start`
```

Each [release](https://github.com/ChihuahuaChain/chihuahua/releases) ships static
linux/amd64 and linux/arm64 binaries, their sha256 and an `upgrade-info.json`, and the
upgrade proposal carries the same binary URLs with checksums. Verify the sha256 of
whatever you stage. Follow upgrades on
[explorer.chihuahua.wtf/proposals](https://explorer.chihuahua.wtf/proposals) and the
validator announcements; the Node Manager's dashboard shows them too.

## Key & infra security

- **One consensus key, one running node. Ever.** Two nodes signing with the same key =
  double-sign = tombstoned. Don't "warm up" a backup by starting it.
- **Use a sentry or a remote signer for the consensus key.** TMKMS (with HSM support)
  keeps the priv-validator key off the public node and enforces double-sign
  protection independently.
- **The operator account key** (the `$KEY` that holds funds and collects commission) is
  separate from the consensus key: keep it in a hardware wallet, not on the server.
  For a team-run validator, make it a **multisig**; see
  [network.md → Multisig accounts](network.md#multisig-accounts).
- Back up `priv_validator_key.json` and your mnemonic offline.
- Bind RPC, REST and gRPC to localhost and publish them through a reverse proxy if
  you serve them; open only the P2P port.

## Running an IBC relayer

A relayer delivers IBC packets between two chains (transfers, acks, timeouts) and
keeps their light clients fresh. As of 2026-11-10 Chihuahua's only live path is
**Osmosis** (`channel-7` ↔ Osmosis `channel-113`, client `07-tendermint-45`); see
[network.md → IBC status](network.md#ibc-status).

**Lesson from 2026:** almost every Chihuahua client expired because relayers only
updated a client when they relayed packets, and idle paths ran past their trusting
period. Recovering a client takes a governance proposal (#98 failed on a client-state
mismatch; #102 succeeded with a substitute cloned from the subject client). So:

- run the relayer with **periodic client refresh** even when no packets flow
  (Hermes `refresh = true`, the default; for `rly`, `--time-threshold 24h`);
- supervise it with systemd, not from an SSH session that dies at logout;
- keep the relayer key funded on **both** chains and alert on low balances: a relayer
  out of gas silently stops, which looks like "my IBC transfers are stuck".

[Hermes](https://hermes.informal.systems) works with Chihuahua since v9.5.0 (which
fixed the `fee_payer` event it could not parse). Chain entry for its `config.toml`:

```toml
[[chains]]
id = 'chihuahua-1'
rpc_addr = 'https://rpc.chihuahua.wtf'
grpc_addr = 'https://grpc.chihuahua.wtf:443'   # or your own node's :9090
event_source = { mode = 'pull', interval = '1s' }
account_prefix = 'chihuahua'
key_name = 'relayer'
store_prefix = 'ibc'
gas_price = { price = 500, denom = 'uhuahua' }   # the consensus minimum
gas_multiplier = 1.6
max_gas = 4000000
trusting_period = '9days'
```

(`pull` mode polls blocks instead of relying on WebSocket events, which are
best-effort; see [network.md](network.md#websocket-events--subscriptions).) Then
import the key (`hermes keys add --chain chihuahua-1 --mnemonic-file ...`) and relay
the existing channel:

```bash
hermes health-check
hermes start
```

> **Relay the existing channel; don't create a duplicate.** A new channel to Osmosis
> would give every asset a second `ibc/` denom and split liquidity. Look up live
> channel IDs and client status first (`chihuahuad query ibc channel channels`,
> `/ibc/core/client/v1/client_status/<client>`).
