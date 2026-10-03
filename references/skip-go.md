# Cross-chain HUAHUA with Skip Go

Skip Go is an interoperability platform that routes tokens across chains by composing
IBC, CCTP, Hyperlane, Eureka, Axelar, and DEX swaps into a single multi-hop route.
Because Chihuahua is IBC-connected to 30+ Cosmos chains, Skip Go is the cleanest way
to let users **bring funds onto Chihuahua, take HUAHUA off it, or swap HUAHUA for any
other supported asset** without making them hand-build IBC transfers.

Two ways to integrate, depending on how much UI you want to own:
- **Widget** — a drop-in React component. Fastest path to a working bridge/swap UI.
- **API / SDK** — call the routing + message-building endpoints yourself and render
  your own UI.

Docs: https://docs.skip.build/go — always check there for the current API base URL,
schema, and chain support, since the API evolves.

## Table of contents
- [Core concepts](#core-concepts)
- [Option A — the Widget](#option-a--the-widget)
- [Option B — the API / SDK](#option-b--the-api--sdk)
- [Acquiring HUAHUA (funding a treasury or faucet)](#acquiring-huahua-funding-a-treasury-or-faucet)
- [Chihuahua-specific notes](#chihuahua-specific-notes)
- [Verifying a transfer landed](#verifying-a-transfer-landed)

## Core concepts

The Skip Go flow is always three phases:

1. **Route** — ask Skip for the best path given a source asset/chain and a
   destination asset/chain (and an amount). It returns the operations (IBC hops,
   swaps, bridges) and expected output.
2. **Messages** — ask Skip to turn that route into ready-to-sign transactions, given
   the user's addresses on each chain in the path.
3. **Submit & track** — sign and broadcast each tx in order, then poll Skip's track
   endpoint until the funds arrive on the destination (multi-hop transfers settle
   asynchronously as packets relay).

Identifiers you'll need for Chihuahua:
- **Chain ID:** `chihuahua-1`
- **Native denom:** `uhuahua` (HUAHUA, 6 decimals)
- HUAHUA arriving on another chain is an IBC voucher (`ibc/<HASH>`); the hash differs
  per destination chain and per channel. Let Skip resolve denoms — don't hardcode
  voucher hashes.

## Option A — the Widget

```bash
npm install @skip-go/widget
```

```tsx
import { Widget } from "@skip-go/widget";

export function Bridge() {
  return (
    <Widget
      theme="dark"
      // Land users on Chihuahua by default:
      defaultRoute={{
        destChainId: "chihuahua-1",
        destAssetDenom: "uhuahua",
      }}
    />
  );
}
```

The widget handles wallet connection (Keplr, MetaMask and others), route discovery, signing
each hop, and progress tracking. Pin the source or destination to `chihuahua-1` to
make your app's bridge feel native. Check the widget's current prop names against the
docs — the config surface changes between versions.

## Option B — the API / SDK

Install the client library:

```bash
npm install @skip-go/client
```

Sketch of the route → messages → submit flow (confirm method names against the
current `@skip-go/client` docs — the SDK API is versioned):

```ts
import { SkipClient } from "@skip-go/client";

const skip = new SkipClient(/* options: endpoints, signers per chain */);

// 1. find a route: e.g. ATOM on the Hub -> HUAHUA on Chihuahua
const route = await skip.route({
  amountIn: "1000000",                 // 1 ATOM (uatom, 6dp)
  sourceAssetDenom: "uatom",
  sourceAssetChainId: "cosmoshub-4",
  destAssetDenom: "uhuahua",
  destAssetChainId: "chihuahua-1",
});

// 2. provide the user's address on every chain the route touches
const userAddresses = route.requiredChainAddresses.map((chainId) => ({
  chainId,
  address: /* the user's bech32 address on that chain */,
}));

// 3. execute — the SDK signs + broadcasts each hop and tracks settlement
await skip.executeRoute({
  route,
  userAddresses,
  onTransactionTracked: (tx) => console.log("hop landed", tx),
});
```

If you'd rather call the raw HTTP API (no SDK), the endpoint shapes are
`POST .../v2/fungible/route` (routing) and `POST .../v2/fungible/msgs` (message
building), plus a track endpoint. Get the exact base URL and request/response schema
from https://docs.skip.build/go/api-reference — don't guess the host, as the API
domain has changed over time.

## Acquiring HUAHUA (funding a treasury or faucet)

A common dev need: you have funds on some other chain and you need **HUAHUA on
Chihuahua** — to seed a faucet, fund a treasury, or pay gas for contract deploys.
Two routes:

1. **One-shot via Skip Go (recommended).** A Skip route from your source asset to
   `uhuahua` on `chihuahua-1` does the swap *and* the IBC delivery in one flow, so you
   don't manually bridge to Osmosis, swap, then bridge onward. Use the route → messages
   → submit pattern above with `destAssetDenom: "uhuahua"`, `destAssetChainId:
   "chihuahua-1"`. Under the hood Skip typically swaps on **Osmosis** (the deepest
   HUAHUA market, the HUAHUA/OSMO pair) and IBCs the result to Chihuahua.

2. **Manual on Osmosis.** IBC your asset to Osmosis, swap for HUAHUA in the HUAHUA/OSMO
   pool (via the Osmosis app or `osmosisd`), then IBC the HUAHUA to your Chihuahua
   address. More steps, more relayer waits, but no dependency on Skip's coverage.

> **HUAHUA liquidity is thin.** The HUAHUA/OSMO market is small (low-thousands of
> dollars of daily volume at times), so a large buy moves the price hard. Split big
> acquisitions, set a sane slippage bound, and check the quote before committing. For
> *trading within Chihuahua itself*, the native DEX **Huahuaswap** is the venue — see
> [ecosystem.md](ecosystem.md#huahuaswap--the-native-dex).

## Chihuahua-specific notes

- **Gas on the Chihuahua hop is paid in HUAHUA.** If a route's final hop executes on
  `chihuahua-1` (e.g. a swap), the user needs a little `uhuahua` for fees. A pure IBC
  receive doesn't, but a swap-on-arrival does — surface this so users aren't stranded
  with a contract call they can't pay for.
- **Chain support is dynamic.** Whether a *specific* asset/route through Chihuahua is
  available depends on Skip's current chain/asset coverage. Query the route endpoint
  and handle "no route found" gracefully rather than assuming every pair works.
- **Always show expected-output and slippage.** Multi-hop routes can include swaps;
  display Skip's estimated output and let the user set slippage before signing.

## Verifying a transfer landed

A cross-chain transfer isn't done when the source tx commits — packets still need to
relay. Confirm arrival on Chihuahua by either:

- Polling Skip's track endpoint (or the SDK's `onTransactionTracked`/status) until it
  reports success on the destination, or
- Checking the destination balance directly on Chihuahua:
  ```bash
  curl -s "https://api.chihuahua.wtf/cosmos/bank/v1beta1/balances/chihuahua1...recipient" | jq
  ```
  (see [network.md](network.md) for endpoints and [dapp-dev.md](dapp-dev.md) for the
  CosmJS `getAllBalances` equivalent).

Treat "source tx succeeded" as "in flight," not "delivered" — only the destination
balance or a success status from the tracker means the funds actually arrived.
