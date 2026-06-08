# Chihuahua Ecosystem: Huahuaswap, Tokens & NFTs

Chihuahua is a meme chain, and the most on-theme thing to build here is a **token**
and trade it on the chain's native DEX. This guide covers the native ecosystem apps
and the CosmWasm patterns for launching your own assets:

- [Huahuaswap — the native DEX](#huahuaswap--the-native-dex)
- [Launch a meme token — two paths](#launch-a-meme-token--two-paths)
  - [Native factory denom (tokenfactory) — recommended](#native-factory-denom-tokenfactory--recommended)
  - [cw20 contract token — portable alternative](#cw20-contract-token--portable-alternative)
- [NFTs (cw721)](#nfts-cw721)
- [Other DeFi venues](#other-defi-venues)

Everything here builds on the CosmWasm and CosmJS mechanics in
[smart-contracts.md](smart-contracts.md) and [dapp-dev.md](dapp-dev.md) — a token is
just a contract, a DEX swap is just an `execute`, an NFT is just another contract.

> **Addresses drift — don't hardcode them blind.** Ecosystem contract addresses
> (DEX router, pool factory, specific pools) change as projects redeploy. Always
> resolve the *current* address from the app's site, by querying the chain
> (`chihuahuad query wasm list-contract-by-code <id>`), or by browsing the
> [Mintscan CosmWasm tab](https://www.mintscan.io/chihuahua) — rather than pasting a
> stale address from a tutorial. The patterns below are stable; the addresses are not.

## Huahuaswap — the native DEX

[huahuaswap.com](https://huahuaswap.com/pools) is Chihuahua's native DEX, built for
meme tokens and liquidity pools. It's a CosmWasm AMM, so you interact with it exactly
like any other contract.

**Find the current contracts.** Get the router/factory and pool addresses from the
Huahuaswap app (its frontend config) or by listing contracts under its code IDs.
Then a swap is a `wasm execute` against the pool/router with a swap message, and
providing liquidity is an `execute` that deposits both sides of the pair.

Typical swap shape (the exact message schema is defined by Huahuaswap's contracts —
query the pool's `{ "pair": {} }` / config to confirm field names before building):

```bash
# query a pool's state / config to learn its message schema and reserves
chihuahuad query wasm contract-state smart <POOL_CONTRACT> '{"pool":{}}' \
  --node "$NODE" --output json | jq

# swap uhuahua -> token via the pool (schema varies; this is the common terraswap/
# wasmswap shape). Native funds go in --amount; the message names the offer asset.
chihuahuad tx wasm execute <POOL_CONTRACT> \
  '{"swap":{"offer_asset":{"info":{"native_token":{"denom":"uhuahua"}},"amount":"1000000"},"max_spread":"0.05"}}' \
  --amount 1000000uhuahua --from "$KEY" $TXFLAGS
```

From a dApp, this is `SigningCosmWasmClient.execute(...)` with the same message — see
[dapp-dev.md](dapp-dev.md#talk-to-a-cosmwasm-contract). Always set a slippage bound
(`max_spread`) and show the user the expected output from a pre-swap simulation
query; thin pools move on small trades.

## Launch a meme token — two paths

Chihuahua gives you two ways to mint a fungible token. On Chihuahua, prefer the
**native factory denom** (the chain has the `x/tokenfactory` module) — there's no
contract to deploy, maintain, or migrate. Use **cw20** only when you specifically need
contract-level logic or cross-chain portability of the exact same standard.

### Native factory denom (tokenfactory) — recommended

Chihuahua ships the `x/tokenfactory` module, so any account can mint a **native**
denom of the form `factory/<your-address>/<subdenom>` with no contract at all. The
creator becomes the admin (can mint/burn/change admin). This is the cleanest way to
launch a meme token on Chihuahua:

```bash
# 1. create the denom (subdenom is your ticker, lowercased). Costs a small fee.
chihuahuad tx tokenfactory create-denom woof --from "$KEY" $TXFLAGS
# -> your full denom is now: factory/<your-chihuahua-address>/woof

DENOM_FULL="factory/$(chihuahuad keys show $KEY -a)/woof"

# 2. mint supply to yourself (amount is in the denom's base units)
chihuahuad tx tokenfactory mint "1000000000000${DENOM_FULL}" --from "$KEY" $TXFLAGS

# 3. (optional) set human metadata: display symbol, exponent, description
#    via tx tokenfactory set-denom-metadata or a bank metadata tx — check
#    `chihuahuad tx tokenfactory --help` for the exact subcommand on this binary.

# 4. (optional) renounce admin so supply can never change again — meme-credibility:
chihuahuad tx tokenfactory change-admin "$DENOM_FULL" \
  chihuahua1zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzdkqkz9 --from "$KEY" $TXFLAGS
```

If you want to *keep* mint control but not trust a single hot key with it, point
`change-admin` at a **multisig** address instead of burning it — see
[network.md → Multisig accounts](network.md#multisig-accounts). That's the middle
ground between "one key can inflate forever" and "supply frozen forever."

(Exact subcommand names can vary slightly by binary version — run
`chihuahuad tx tokenfactory --help` to confirm `create-denom`/`mint`/`burn`/
`change-admin`/`set-denom-metadata`.) Because it's a native bank denom, it works
everywhere `uhuahua` does: `bank send`, balances, Huahuaswap pools, IBC.

### cw20 contract token — portable alternative

The portable CosmWasm path is the **cw20** standard contract. Upload the standard
`cw20-base` wasm once (or reuse an existing code ID on-chain), then instantiate:

```bash
chihuahuad tx wasm instantiate <CW20_CODE_ID> '{
  "name": "Doge Of Chihuahua",
  "symbol": "WOOF",
  "decimals": 6,
  "initial_balances": [
    {"address": "'"$(chihuahuad keys show $KEY -a)"'", "amount": "1000000000000"}
  ],
  "mint": {"minter": "'"$(chihuahuad keys show $KEY -a)"'"}
}' --label "WOOF token" --admin "$(chihuahuad keys show $KEY -a)" \
   --from "$KEY" $TXFLAGS
```

Either way, to list on Huahuaswap create a `WOOF`/`uhuahua` pair through the DEX's
factory contract and seed it with liquidity; after that anyone can trade it.
(`cw20-base` and `cw721-base` wasm come from the CosmWasm `cw-plus`/`cw-nfts` repos;
build them with the optimizer like any contract — see
[smart-contracts.md](smart-contracts.md#step-2--compile--optimize-reproducible-build).)

## NFTs (cw721)

NFTs run on Chihuahua as CosmWasm **cw721** contracts (the Cosmos analog of ERC-721) —
the chain's CosmWasm support means a standard NFT contract deploys and runs here like
on any wasm chain. A collection is one contract; each token is an entry inside it.
Instantiate a collection from the standard `cw721-base` code:

```bash
chihuahuad tx wasm instantiate <CW721_CODE_ID> '{
  "name": "Chihuahua Pups",
  "symbol": "PUPS",
  "minter": "'"$(chihuahuad keys show $KEY -a)"'"
}' --label "Chihuahua Pups" --from "$KEY" $TXFLAGS

# mint token #1 with metadata
chihuahuad tx wasm execute <COLLECTION_CONTRACT> '{
  "mint": {"token_id":"1","owner":"chihuahua1...","token_uri":"ipfs://<CID>"}
}' --from "$KEY" $TXFLAGS

# query who owns it
chihuahuad query wasm contract-state smart <COLLECTION_CONTRACT> \
  '{"owner_of":{"token_id":"1"}}' --node "$NODE" --output json | jq
```

Host metadata/images on IPFS and put the `ipfs://` URI in `token_uri`. From a dApp,
mint and query through `SigningCosmWasmClient` / `CosmWasmClient` exactly as in
[dapp-dev.md](dapp-dev.md).

## Chihuahua reference contracts (Chiwawasm)

The chain team publishes its own CosmWasm contracts in
[ChihuahuaChain/Chiwawasm](https://github.com/ChihuahuaChain/Chiwawasm) — the best
Chihuahua-specific reference for the patterns this page describes, because it's
real code written for this chain rather than a generic template:

| Contract | What it does | Study it for |
|----------|--------------|--------------|
| `token-swap` | Constant-product (AMM) pool that trades any cw20 or IBC token quoted against the base **HUAHUA** | The DEX/pool message shape — how a swap, a pool, and liquidity are modeled against `uhuahua`. This is the on-chain analog of the Huahuaswap swap above. |
| `tokens-manager` | Lets users pay a `token_creation_fee` to mint **cw20** tokens managed by the contract | A fee-gated token-launch pattern, if you want minting through a contract rather than the native tokenfactory path. |
| `burn-contract` | Burns token balances | A minimal, readable contract to learn the `instantiate`/`execute`/`query` shape end to end. |

> **Treat it as a reference to study, not deploy-as-is.** The repo is lightly
> maintained and its tooling is dated: it pins `cosmwasm/rust-optimizer:0.12.6` and
> its CLI examples use the template `stake` denom. When you adapt anything from it,
> build with the **current** optimizer (`cosmwasm/optimizer:0.16.0`, see
> [smart-contracts.md](smart-contracts.md#step-2--compile--optimize-reproducible-build))
> and use **`uhuahua`**, not `stake`. Read the message schemas directly from each
> contract's `msg.rs` — that's the source of truth for its execute/query JSON.

## Other DeFi venues

- **White Whale** — liquidity pools and flash loans are live on Chihuahua; another
  CosmWasm venue you can route swaps through.
- **Osmosis** — the deepest cross-chain HUAHUA market (HUAHUA/OSMO), reached via IBC.
  See [skip-go.md → Acquiring HUAHUA](skip-go.md#acquiring-huahua-funding-a-treasury-or-faucet)
  for funding an account with HUAHUA from another chain.
- **Sienna (Secret)** — `sHUAHUA` exists as a privacy-wrapped form on Secret Network.

These are independent projects; confirm a venue is active and pull its current
contract addresses from its own app before integrating.
