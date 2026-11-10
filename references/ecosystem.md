# Chihuahua Ecosystem: dApps, Huahuaswap, Tokens & NFTs

Chihuahua is a meme chain, and the most on-theme things to build here are tokens and
the apps around them. This guide covers the live ecosystem dApps, the native DEX and
its launchpad, and how to launch and burn your own assets:

- [Ecosystem at a glance](#ecosystem-at-a-glance)
- [Huahuaswap: the native DEX](#huahuaswap-the-native-dex)
- [The Huahuaswap launchpad](#the-huahuaswap-launchpad)
- [Launch a meme token: two paths](#launch-a-meme-token-two-paths)
  - [Native factory denom (tokenfactory)](#native-factory-denom-tokenfactory)
  - [cw20 contract token: portable alternative](#cw20-contract-token-portable-alternative)
- [Burning HUAHUA and tokens](#burning-huahua-and-tokens)
- [NFTs (cw721)](#nfts-cw721)
- [Chihuahua reference contracts (Chiwawasm)](#chihuahua-reference-contracts-chiwawasm)
- [Other venues](#other-venues)

Everything here builds on the CosmWasm and CosmJS mechanics in
[smart-contracts.md](smart-contracts.md) and [dapp-dev.md](dapp-dev.md).

> **Addresses drift: don't hardcode them blind.** Ecosystem contract addresses change
> as projects redeploy. Resolve the *current* address from the app, by querying the
> chain (`chihuahuad query wasm list-contract-by-code <id>`), and by checking it on
> [explorer.chihuahua.wtf](https://explorer.chihuahua.wtf) (`/account/<address>` shows
> the contract label). The addresses below were checked on 2026-11-10.

## Ecosystem at a glance

| App | What it is |
|-----|------------|
| [Huahuaswap](https://swap.chihuahua.wtf) | Native DEX (x/liquidity pools against HUAHUA) and memecoin launchpad. `huahuaswap.com` redirects here. |
| [Huahua P2P](https://p2p.chihuahua.wtf) | Peer-to-peer escrow exchange between any two listed tokens, with an agent API paid through x402; see [p2p-agents.md](p2p-agents.md) |
| [Dogtags](https://tags.chihuahua.wtf) | Name service: a readable name for a `chihuahua1...` address |
| [Huahua Prediction](https://predict.chihuahua.wtf) | BTC and ETH up-or-down rounds, in USDC |
| [Woof Morning](https://wm.chihuahua.wtf) | Daily "woof" streak game with soulbound badges and seasonal NFT pups |
| [Burn tracker](https://burn.chihuahua.wtf) | HUAHUA burned forever |
| [Huallet](https://github.com/ChihuahuaChain/huallet) | Chihuahua's own wallet: Chrome, Firefox and Android; `window.huallet` speaks the Keplr API |
| [explorer.chihuahua.wtf](https://explorer.chihuahua.wtf) | The chain's own block explorer |

**Dogtags** (mainnet contract `chihuahua1zqmhmz9weyrngl3v8gfprcuygv6fsgw9j9fwu42syegeryqyz2yshrznzx`)
resolves both ways, which is handy to show names instead of addresses:

```bash
chihuahuad query wasm contract-state smart <DOGTAGS> '{"resolve":{"alias":"burn"}}' --node "$NODE"
chihuahuad query wasm contract-state smart <DOGTAGS> '{"reverse":{"address":"chihuahua1..."}}' --node "$NODE"
```

## Huahuaswap: the native DEX

[swap.chihuahua.wtf](https://swap.chihuahua.wtf) is Chihuahua's DEX. Its pools are the
chain's own **`x/liquidity` module** (the Gravity DEX design, maintained in the
chain repo), not a CosmWasm contract. Each pool pairs a token with `uhuahua`; prices
come from the ratio of the reserves.

| Parameter | Value (2026-11-10) |
|-----------|--------------------|
| Swap fee | 0.5% (`swap_fee_rate` 0.005) |
| Max order | 10% of the pool's reserve (`max_order_amount_ratio`) |
| Batch | every block (`unit_batch_height` 1) |

```bash
# pools: id, the two reserve denoms, the reserve account (read its balances for the price)
curl -s "https://api.chihuahua.wtf/cosmos/liquidity/v1beta1/pools?pagination.limit=200" | jq '.pools[] | {id, reserve_coin_denoms, reserve_account_address}'
curl -s https://api.chihuahua.wtf/cosmos/liquidity/v1beta1/params | jq
```

Two ways to swap, both with a limit price:

```bash
# immediate swap against the pool
chihuahuad tx liquidity direct-swap <POOL_ID> 1 1000000uhuahua <DEMAND_DENOM> <ORDER_PRICE> --from "$KEY" $TXFLAGS

# batch swap: executed at the end of the block at one price for every order in the batch
# (front-running resistant); reserves half the swap fee up front
chihuahuad tx liquidity swap <POOL_ID> 1 1000000uhuahua <DEMAND_DENOM> <ORDER_PRICE> 0.005 --from "$KEY" $TXFLAGS
```

`ORDER_PRICE` is the exchange ratio X/Y, where X and Y are the two reserve coins
**sorted alphabetically by denom** (`factory/...` sorts before `uhuahua`). Read the
reserves first and set a price with a slippage bound you accept; the swap fills only
at that price or better. From code, the messages are
`/liquidity.v1beta1.MsgDirectSwap` and `/liquidity.v1beta1.MsgSwapWithinBatch` (proto
package `liquidity.v1beta1` in the chain repo; they are not in `cosmjs-types`, so
register them yourself or send them through the CLI). Pools are thin: always quote
from the reserves and show the user the expected output.

## The Huahuaswap launchpad

Memecoins launched on Huahuaswap go through the `huahua-factory` CosmWasm contract
`chihuahua1sj9verkuk8aa9jrngnpwup6zjht4vwngjlpemnt9w38ccp0qnlcswvsuzc`: it creates a
tokenfactory denom `factory/<factory>/<subdenom>`, sells it along a **bonding curve**,
and when the curve completes ("graduates") the token moves to a Huahuaswap pool.
Create and buy through the app; read the state from the contract:

```bash
FACTORY=chihuahua1sj9verkuk8aa9jrngnpwup6zjht4vwngjlpemnt9w38ccp0qnlcswvsuzc
# every launched token, 50 per page (pass "start_after":"<subdenom>" for the next page)
chihuahuad query wasm contract-state smart $FACTORY '{"get_tokens_with_pagination":{"limit":50}}' --node "$NODE" --output json \
  | jq '.data.tokens[] | {subdenom, name, denom, completed}'
# one token
chihuahuad query wasm contract-state smart $FACTORY '{"token_info":{"subdenom":"beer"}}' --node "$NODE"
```

`completed: true` means the bonding curve is done. Some apps treat graduated tokens
specially (Huahua P2P lists them for free).

## Launch a meme token: two paths

On Chihuahua, prefer the **native factory denom** (`x/tokenfactory`): there's no
contract to deploy, maintain or migrate. Use **cw20** only when you need
contract-level logic or the exact cw20 standard. (Or launch through the
[launchpad](#the-huahuaswap-launchpad) to get a bonding curve and a pool.)

### Native factory denom (tokenfactory)

Any account can create a **native** denom `factory/<your-address>/<subdenom>`. The
creator becomes its admin. Creating one costs **10 HUAHUA** (`denom_creation_fee`)
plus gas.

```bash
# 1. create the denom (subdenom is your ticker, lowercased)
chihuahuad tx tokenfactory create-denom woof --from "$KEY" $TXFLAGS
DENOM_FULL="factory/$(chihuahuad keys show $KEY -a)/woof"

# 2. mint supply to yourself (base units of the denom), or to someone else
chihuahuad tx tokenfactory mint "1000000000000${DENOM_FULL}" --from "$KEY" $TXFLAGS
chihuahuad tx tokenfactory mint-to chihuahua1... "1000000${DENOM_FULL}" --from "$KEY" $TXFLAGS

# 3. human metadata: ticker, description, exponent (6 like HUAHUA)
chihuahuad tx tokenfactory modify-metadata "$DENOM_FULL" WOOF "The goodest boy token" 6 --from "$KEY" $TXFLAGS

# 4. (optional) renounce admin so supply and balances can never be touched again:
#    hand it to the all-zero address, which no key controls
chihuahuad tx tokenfactory change-admin "$DENOM_FULL" \
  chihuahua1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqskd3xl --from "$KEY" $TXFLAGS
```

> **A denom admin is powerful on Chihuahua.** Besides `mint` and `burn`, the admin can
> `force-transfer` the token out of any account and `burn-from` any account,
> including a contract's escrow. That's why holders look at who the admin is:
> `chihuahuad query tokenfactory denom-authority-metadata "$DENOM_FULL"`. Renounce
> it (step 4) for a fixed-supply meme token, or point it at a **multisig** if you need
> to keep mint control without trusting one hot key; see
> [network.md → Multisig accounts](network.md#multisig-accounts).

Run `chihuahuad tx tokenfactory --help` for the full list (it also has
`create-stakedrop`, which lets a token's creator drop it to stakers between two block heights). Because
it's a native bank denom, it works everywhere `uhuahua` does: `bank send`, balances,
Huahuaswap pools, IBC.

### cw20 contract token: portable alternative

Upload the standard `cw20-base` wasm once (or reuse an existing code ID on chain),
then instantiate:

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

Note that Huahuaswap pools (`x/liquidity`) take native denoms, so a cw20 token
cannot be pooled there directly; that's another reason to prefer tokenfactory.
(`cw20-base` and `cw721-base` come from the CosmWasm `cw-plus`/`cw-nfts` repos; build
them with the optimizer like any contract; see
[smart-contracts.md](smart-contracts.md#step-2-compile--optimize-reproducible-build).)

## Burning HUAHUA and tokens

Send HUAHUA or any tokenfactory denom to the x/feeburn module account
`chihuahua1d99pujdz48wkmn3uesfxnrctn44uuf5cuw5xuu` (Dogtags alias `burn`). It is
burned at the end of the block and added to the chain's public burned total
(`/chihuahua/feeburn/total_burned`, shown on [burn.chihuahua.wtf](https://burn.chihuahua.wtf)):

```bash
chihuahuad tx bank send "$KEY" chihuahua1d99pujdz48wkmn3uesfxnrctn44uuf5cuw5xuu 1000000000uhuahua $TXFLAGS
```

IBC vouchers sent there are **not** burned (they stay untouched), so never send an
`ibc/...` token to it. The token admin can also burn its own tokenfactory denom with
`tx tokenfactory burn`.

## NFTs (cw721)

NFTs run on Chihuahua as CosmWasm **cw721** contracts. A collection is one contract;
each token is an entry inside it. Instantiate a collection from the standard
`cw721-base` code:

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

Host metadata and images on IPFS and put the `ipfs://` URI in `token_uri`. The
chain's own `x/nft` module was removed in v10: cw721 is the NFT standard here.

## Chihuahua reference contracts (Chiwawasm)

The chain team publishes example CosmWasm contracts in
[ChihuahuaChain/Chiwawasm](https://github.com/ChihuahuaChain/Chiwawasm):

| Contract | What it does | Study it for |
|----------|--------------|--------------|
| `token-swap` | Constant-product (AMM) pool that trades any cw20 or IBC token quoted against **HUAHUA** | How a swap, a pool and liquidity are modeled as a contract against `uhuahua` |
| `tokens-manager` | Lets users pay a `token_creation_fee` to mint **cw20** tokens managed by the contract | A fee-gated token-launch pattern |
| `burn-contract` | Burns token balances | A minimal, readable contract to learn the `instantiate`/`execute`/`query` shape end to end |

> **Study it, don't deploy it as-is.** The repo is lightly maintained and its tooling
> is dated: it pins `cosmwasm/rust-optimizer:0.12.6` and its CLI examples use the
> template `stake` denom. Build anything you adapt with the current optimizer
> (`cosmwasm/optimizer:0.17.0`) and use **`uhuahua`**. Read the message schemas from
> each contract's `msg.rs`.

## Other venues

- **Osmosis** is the deepest cross-chain HUAHUA market (HUAHUA/OSMO) and, as of
  2026-11-10, Chihuahua's only live IBC path. See
  [skip-go.md](skip-go.md#acquiring-huahua-funding-a-treasury-or-faucet) to fund an
  account with HUAHUA from another chain.

Confirm a venue is active and pull its current contract addresses from its own app
before integrating.
