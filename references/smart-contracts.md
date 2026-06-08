# CosmWasm Smart Contracts on Chihuahua

Chihuahua runs the CosmWasm (`x/wasm`) module, so contracts are WebAssembly compiled
from **Rust**. This guide takes you from a blank contract to a live, queried contract
on `chihuahua-1`. The lifecycle is always: **write → compile → optimize → store
(get a code ID) → instantiate (get a contract address) → execute / query.**

> Rehearse the whole flow on the **local devnet** first (see
> [network.md → Local devnet](network.md#local-devnet-your-safe-sandbox)). On a
> local chain `store-code` is always open and tokens are free, so a mistake costs
> nothing. Only promote to mainnet once it works end to end.

## Table of contents
- [Prerequisites](#prerequisites)
- [Step 1 — Scaffold a contract](#step-1--scaffold-a-contract)
- [Step 2 — Compile & optimize (reproducible build)](#step-2--compile--optimize-reproducible-build)
- [Step 0.5 — Check upload permissions FIRST](#step-05--check-upload-permissions-first)
- [Step 3 — Store the code (permissionless path)](#step-3--store-the-code-permissionless-path)
- [Step 3-gov — Store via governance (permissioned path)](#step-3-gov--store-via-governance-permissioned-path)
- [Step 4 — Instantiate](#step-4--instantiate)
- [Step 5 — Execute & query](#step-5--execute--query)
- [Migrations](#migrations)
- [Gotchas](#gotchas)

## Prerequisites

```bash
rustup target add wasm32-unknown-unknown   # the wasm compile target
cargo install cargo-generate --features vendored-openssl
docker --version                           # needed for the optimizer
chihuahuad version                          # the chain CLI (see network.md)
```

Set your network context once (used by every command below):

```bash
export CHAIN_ID=chihuahua-1
export NODE=https://rpc.chihuahua.wtf
export TXFLAGS="--chain-id $CHAIN_ID --node $NODE --gas auto --gas-adjustment 1.4 --gas-prices 1250uhuahua -y -b sync"
export KEY=mykey   # a key created with `chihuahuad keys add`
```

## Step 1 — Scaffold a contract

Use the official template — it gives you a compiling counter contract with the
standard `instantiate`/`execute`/`query` entry points:

```bash
cargo generate --git https://github.com/CosmWasm/cw-template.git --name my-contract -d minimal=true
cd my-contract
```

The shape you'll fill in:
- `InstantiateMsg` — params set once at creation.
- `ExecuteMsg` — enum of state-changing actions.
- `QueryMsg` — enum of read-only questions, each with a response type.
- `state.rs` — `cw-storage-plus` `Item`/`Map` for persisted state.

## Step 2 — Compile & optimize (reproducible build)

Never store a raw `cargo build` artifact — it's bloated and non-reproducible. Use the
CosmWasm **optimizer** Docker image, which strips and `wasm-opt`s the binary so the
on-chain code is small and deterministically hashable:

```bash
# from the contract root; arm64 Macs use the -arm64 image tag
docker run --rm -v "$(pwd)":/code \
  --mount type=volume,source="$(basename "$(pwd)")_cache",target=/code/target \
  --mount type=volume,source=registry_cache,target=/usr/local/cargo/registry \
  cosmwasm/optimizer:0.16.0
```

Output lands in `artifacts/my_contract.wasm`. Sanity-check the size (should be tens
to a few hundred KB, not multiple MB):

```bash
ls -lh artifacts/*.wasm
```

## Step 0.5 — Check upload permissions FIRST

Chihuahua's `code_upload_access` may be **permissionless** (anyone can `store-code`)
or **governance-gated** (only approved addresses, or only via a passed proposal).
This is a chain parameter that can change, so check it before you build a deploy
plan — don't assume:

```bash
chihuahuad query wasm params --node "$NODE" --output json | jq
```

Read `code_upload_access.permission`:
- `Everybody` → permissionless. Use [Step 3](#step-3--store-the-code-permissionless-path).
- `Nobody` → uploads are fully closed; you must go through governance
  ([Step 3-gov](#step-3-gov--store-via-governance-permissioned-path)).
- `AnyOfAddresses` → only the listed addresses can upload. If you're not on the
  list, you need a governance proposal or a whitelisted deployer.

Also note `instantiate_default_permission` — even if you can upload, instantiation
may be restricted.

## Step 3 — Store the code (permissionless path)

```bash
chihuahuad tx wasm store artifacts/my_contract.wasm --from "$KEY" $TXFLAGS
```

Storing is gas-heavy (you're paying to persist the whole wasm blob) — expect a much
larger fee than a normal tx. Grab the **code ID** from the tx events:

```bash
TXHASH=<from the broadcast output>
chihuahuad query tx "$TXHASH" --node "$NODE" --output json \
  | jq -r '.events[] | select(.type=="store_code") | .attributes[] | select(.key=="code_id").value'
```

## Step 3-gov — Store via governance (permissioned path)

If uploads are gated, submit a `store-code` (or store-and-instantiate) governance
proposal and rally a vote. Modern wasmd exposes this as a gov-wrapped store:

```bash
chihuahuad tx wasm submit-proposal wasm-store artifacts/my_contract.wasm \
  --title "Store my-contract" \
  --summary "CosmWasm code for <what it does>" \
  --instantiate-anyof-addresses "$(chihuahuad keys show $KEY -a)" \
  --deposit 10000000000uhuahua \
  --from "$KEY" $TXFLAGS
```

(Exact subcommand/flags depend on the wasmd version baked into the chain's binary —
if `submit-proposal wasm-store` is missing, check `chihuahuad tx gov submit-proposal
--help` and `chihuahuad tx wasm --help`.) After the voting period passes, the code ID
exists and you can instantiate. Budget days, not minutes, for a governance path — and
post in the Chihuahua community channels first so validators expect the proposal.

## Step 4 — Instantiate

Turn a code ID into a live contract. `--label` is a human tag; `--admin` controls who
can later migrate it (use `--no-admin` to make it immutable). For anything holding
value, set `--admin` to a **multisig** rather than a single hot key, so a migration
needs multiple approvals — see [network.md → Multisig accounts](network.md#multisig-accounts):

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

## Step 5 — Execute & query

Query (free, read-only — the JSON key is the `QueryMsg` variant):

```bash
CONTRACT=<chihuahua1... contract address>
chihuahuad query wasm contract-state smart "$CONTRACT" '{"get_count": {}}' \
  --node "$NODE" --output json | jq
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
contracts and a footgun if you shipped a bug — decide deliberately at instantiate
time.

## Gotchas

- **Optimizer image must match your contract's cosmwasm-std.** A mismatch produces a
  wasm the chain rejects at store time with a validation error. Pin the optimizer
  version to one compatible with your `Cargo.toml` deps.
- **arm64 vs x86 optimizer.** On Apple Silicon use `cosmwasm/optimizer-arm64`, but be
  aware arm64 builds are NOT byte-identical to x86 — for a reproducible/verifiable
  build that others can check, produce the final artifact on x86.
- **Amounts are uhuahua.** `--amount` and any amount field in a message is in micro-
  units. 1 HUAHUA = `1000000uhuahua`.
- **Broadcast mode.** `-b sync` returns once the tx is accepted into the mempool; then
  poll `query tx <hash>`. Don't assume success from the broadcast alone — check the
  `code` field on the committed tx.
- **Dead endpoint ≠ contract bug.** Connection refused / timeout means the public node
  is down. Switch `$NODE` to another from [network.md](network.md#rpc-endpoints).

## Learning & reference

- **New to CosmWasm or Rust?** [Area-52](https://area-52.io/) is a free, interactive
  "learn by doing" course (built by Phi Labs, incubated at the founding Cosmos team)
  that walks you from zero to a deployed contract. Best starting point if the Rust +
  contract model is unfamiliar.
- **Authoritative contract-authoring docs:** the official
  [CosmWasm documentation](https://cosmwasm.github.io/) — entry points, `cw-storage-plus`
  storage, `MultiTest` testing, IBC, and the contract semantics this guide assumes.
  Treat it as the source of truth for the *authoring* details; this skill covers the
  *Chihuahua deployment* specifics around it.
- **Chihuahua's own example contracts:** [Chiwawasm](https://github.com/ChihuahuaChain/Chiwawasm)
  (AMM, cw20 minting, burn) — see
  [ecosystem.md](ecosystem.md#chihuahua-reference-contracts-chiwawasm) for what each
  one teaches and the caveat about its dated tooling.
