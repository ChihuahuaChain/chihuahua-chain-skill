# CosmWasm Smart Contracts on Chihuahua

Chihuahua runs the CosmWasm (`x/wasm`) module (wasmd v0.70, wasmvm v3 since v10), so
contracts are WebAssembly compiled from **Rust**. This guide takes you from a blank
contract to a live, queried contract on `chihuahua-1`. The lifecycle is always:
**write → compile → optimize → store (get a code ID) → instantiate (get a contract
address) → execute / query.**

> Rehearse the whole flow on the **woofnet-6 testnet** first (free HUAHUA from its
> faucet, same binary, upload open to everybody; see
> [network.md → Testnet](network.md#testnet-woofnet-6)). A mistake there costs
> nothing. Only promote to mainnet once it works end to end.

## Table of contents
- [Prerequisites](#prerequisites)
- [Step 1: Scaffold a contract](#step-1-scaffold-a-contract)
- [Step 2: Compile & optimize (reproducible build)](#step-2-compile--optimize-reproducible-build)
- [Step 0.5: Check upload permissions FIRST](#step-05-check-upload-permissions-first)
- [Step 3: Store the code](#step-3-store-the-code)
- [Step 3-gov: Store via governance (permissioned path)](#step-3-gov-store-via-governance-permissioned-path)
- [Step 4: Instantiate](#step-4-instantiate)
- [Step 5: Execute & query](#step-5-execute--query)
- [Migrations](#migrations)
- [Burning from a contract](#burning-from-a-contract)
- [Gotchas](#gotchas)

## Prerequisites

```bash
rustup target add wasm32-unknown-unknown   # the wasm compile target
cargo install cargo-generate --features vendored-openssl
cargo install cosmwasm-check               # validates a wasm against the chain's capabilities
docker --version                           # needed for the optimizer
chihuahuad version                         # the chain CLI (see network.md)
```

Set your network context once (used by every command below):

```bash
export CHAIN_ID=chihuahua-1                 # woofnet-6 on the testnet
export NODE=https://rpc.chihuahua.wtf       # https://testnet-rpc.chihuahua.wtf on the testnet
export TXFLAGS="--chain-id $CHAIN_ID --node $NODE --gas auto --gas-adjustment 1.6 --gas-prices 500uhuahua -y -b sync"
export KEY=mykey   # a key created with `chihuahuad keys add`
```

500 uhuahua per gas is the consensus minimum and the 1.6 adjustment covers the
chain's simulation underestimates; see [network.md](network.md#denominations--gas).

## Step 1: Scaffold a contract

Use the official template: it gives you a compiling counter contract with the
standard `instantiate`/`execute`/`query` entry points:

```bash
cargo generate --git https://github.com/CosmWasm/cw-template.git --name my-contract -d minimal=true
cd my-contract
```

The shape you'll fill in:
- `InstantiateMsg`: params set once at creation.
- `ExecuteMsg`: enum of state-changing actions.
- `QueryMsg`: enum of read-only questions, each with a response type.
- `state.rs`: `cw-storage-plus` `Item`/`Map` for persisted state.

**Capabilities.** Contracts built with `cosmwasm-std` 2.x and features up to
`cosmwasm_2_0` run in production on v10. Before storing, check the artifact:
`cosmwasm-check artifacts/my_contract.wasm`. It fails fast on a capability or import
the chain does not offer, instead of at store time.

## Step 2: Compile & optimize (reproducible build)

Never store a raw `cargo build` artifact: it's bloated and non-reproducible. Use the
CosmWasm **optimizer** Docker image, which strips and `wasm-opt`s the binary so the
on-chain code is small and deterministically hashable:

```bash
# from the contract root; arm64 Macs use the -arm64 image tag
docker run --rm -v "$(pwd)":/code \
  --mount type=volume,source="$(basename "$(pwd)")_cache",target=/code/target \
  --mount type=volume,source=registry_cache,target=/usr/local/cargo/registry \
  cosmwasm/optimizer:0.17.0
```

Output lands in `artifacts/my_contract.wasm` (the container writes it as root: fix
ownership with `sudo chown -R $(id -u):$(id -g) artifacts`). Sanity-check the size:
tens to a few hundred KB is normal. The chain accepts up to **1600 KiB** per contract
(since v10.0.1).

```bash
ls -lh artifacts/*.wasm
cosmwasm-check artifacts/*.wasm
```

## Step 0.5: Check upload permissions FIRST

Chihuahua's `code_upload_access` is a governance parameter. As of 2026-11-10 it is
**`Everybody`** (anyone can `store-code`), on mainnet and on woofnet-6. Check before
you build a deploy plan:

```bash
chihuahuad query wasm params --node "$NODE" --output json | jq
# or: curl -s https://api.chihuahua.wtf/cosmwasm/wasm/v1/codes/params
```

Read `code_upload_access.permission`:
- `Everybody`: permissionless. Use [Step 3](#step-3-store-the-code).
- `Nobody`: uploads are closed; go through governance
  ([Step 3-gov](#step-3-gov-store-via-governance-permissioned-path)).
- `AnyOfAddresses`: only the listed addresses can upload.

Also note `instantiate_default_permission` (today `Everybody`).

## Step 3: Store the code

```bash
chihuahuad tx wasm store artifacts/my_contract.wasm --from "$KEY" $TXFLAGS
```

Storing is the most expensive transaction you will send, because you pay to persist
the whole blob. The CLI (and CosmJS `upload`) gzip the wasm before sending, which
roughly halves the gas: a ~400 KB optimized contract takes ~2.7M gas, about
**2,200 HUAHUA** with 1.6 padding at 500 uhuahua per gas. If you build
`MsgStoreCode` by hand, gzip `wasm_byte_code` yourself (wasmd unpacks it and the
code checksum stays the sha256 of the raw wasm); unzipped, it costs about twice as
much. Grab the **code ID** from the tx events:

```bash
TXHASH=<from the broadcast output>
chihuahuad query tx "$TXHASH" --node "$NODE" --output json \
  | jq -r '.events[] | select(.type=="store_code") | .attributes[] | select(.key=="code_id").value'
```

Verify that what landed is what you built:

```bash
chihuahuad query wasm code-info <CODE_ID> --node "$NODE" --output json | jq -r .checksum
sha256sum artifacts/my_contract.wasm
```

## Step 3-gov: Store via governance (permissioned path)

If uploads are ever gated, submit a store-code governance proposal and rally a vote:

```bash
chihuahuad tx wasm submit-proposal wasm-store artifacts/my_contract.wasm \
  --title "Store my-contract" \
  --summary "CosmWasm code for <what it does>" \
  --instantiate-anyof-addresses "$(chihuahuad keys show $KEY -a)" \
  --deposit 50000000000000uhuahua \
  --from "$KEY" $TXFLAGS
```

The minimum deposit is **50,000,000 HUAHUA** (proposal #107; read it live from
`/cosmos/gov/v1/params/deposit`), and at least 25% of it must be attached when the
proposal is submitted. Voting lasts 5 days. Exact subcommand flags depend on the
wasmd version in the binary: check `chihuahuad tx wasm submit-proposal --help`.
Post in the Chihuahua community channels first so validators expect the proposal.

## Step 4: Instantiate

Turn a code ID into a live contract. `--label` is a human tag; `--admin` controls who
can later migrate it (use `--no-admin` to make it immutable). For anything holding
value, set `--admin` to a **multisig** rather than a single hot key, so a migration
needs multiple approvals; see [network.md → Multisig accounts](network.md#multisig-accounts):

```bash
CODE_ID=<from step 3>
chihuahuad tx wasm instantiate "$CODE_ID" '{"count": 0}' \
  --label "my-counter" \
  --admin "$(chihuahuad keys show $KEY -a)" \
  --from "$KEY" $TXFLAGS
```

Get the contract address:

```bash
chihuahuad query wasm list-contract-by-code "$CODE_ID" --node "$NODE" --output json \
  | jq -r '.contracts[-1]'
```

## Step 5: Execute & query

Query (free, read-only; the JSON key is the `QueryMsg` variant):

```bash
CONTRACT=<chihuahua1... contract address>
chihuahuad query wasm contract-state smart "$CONTRACT" '{"get_count": {}}' \
  --node "$NODE" --output json | jq
# over REST: GET /cosmwasm/wasm/v1/contract/$CONTRACT/smart/<base64 of the query JSON>
```

Execute (a tx that mutates state and costs gas):

```bash
chihuahuad tx wasm execute "$CONTRACT" '{"increment": {}}' \
  --from "$KEY" $TXFLAGS
```

Attach funds to an execute (e.g. a contract that takes a HUAHUA deposit) with
`--amount 1000000uhuahua`. Inside the contract those arrive as `info.funds`.

## Migrations

If you instantiated with an `--admin`, you can swap the code under a live contract
(state is preserved; the new code's `migrate` entry point runs):

```bash
chihuahuad tx wasm migrate "$CONTRACT" "$NEW_CODE_ID" '{}' --from "$KEY" $TXFLAGS
```

No admin = no migrations, ever. That immutability is a feature for trust-minimized
contracts and a footgun if you shipped a bug. A common pattern for immutable
contracts that hold funds: a `paused` flag the owner can set, so that a fix means
pausing, deploying a new contract and pointing users at it, while withdrawals and
cancels keep working on the old one.

## Burning from a contract

To burn HUAHUA or a tokenfactory denom from a contract, send it to the x/feeburn
module account `chihuahua1d99pujdz48wkmn3uesfxnrctn44uuf5cuw5xuu` with a plain
`BankMsg::Send`. It is burned at the end of the block and counted in
`/chihuahua/feeburn/total_burned`, so the burn shows up in the chain's public total.
See [network.md → Fee burn](network.md#fee-burn-and-the-burn-address).

## Gotchas

- **Optimizer image must match your contract's cosmwasm-std.** A mismatch produces a
  wasm the chain rejects at store time with a validation error. Run `cosmwasm-check`
  on the artifact first.
- **arm64 vs x86 optimizer.** On Apple Silicon use `cosmwasm/optimizer-arm64`, but
  arm64 builds are NOT byte-identical to x86: for a reproducible, verifiable build
  that others can check, produce the final artifact on x86.
- **Amounts are uhuahua.** `--amount` and any amount field in a message is in
  micro-units. 1 HUAHUA = `1000000uhuahua`.
- **Gas.** Out of gas (code 11) still charges the fee. Keep `--gas-adjustment 1.6`.
- **Broadcast mode.** `-b sync` returns once the tx is accepted into the mempool;
  then poll `query tx <hash>`. Don't assume success from the broadcast alone: check
  the `code` field on the committed tx.
- **Tokenfactory admins can move tokens.** If your contract escrows a
  `factory/...` denom, its denom admin can force-transfer or burn it out of your
  contract (see [ecosystem.md](ecosystem.md#native-factory-denom-tokenfactory)).
  Check `denom-authority-metadata` and warn users when the admin is an account.
- **Dead endpoint ≠ contract bug.** Connection refused / timeout means the public node
  is down. Switch `$NODE` to another from [network.md](network.md#rpc-endpoints).

## Learning & reference

- **New to CosmWasm or Rust?** [Area-52](https://area-52.io/) is a free, interactive
  "learn by doing" course that walks you from zero to a deployed contract.
- **Authoritative contract-authoring docs:** the official
  [CosmWasm documentation](https://cosmwasm.github.io/): entry points,
  `cw-storage-plus` storage, `MultiTest` testing, IBC, and the contract semantics this
  guide assumes. This skill covers the *Chihuahua deployment* specifics around it.
- **Chihuahua's own example contracts:** [Chiwawasm](https://github.com/ChihuahuaChain/Chiwawasm)
  (AMM, cw20 minting, burn); see
  [ecosystem.md](ecosystem.md#chihuahua-reference-contracts-chiwawasm) for what each
  one teaches and the caveat about its dated tooling.
