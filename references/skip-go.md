# Cross-chain HUAHUA: IBC and Skip Go

How to bring funds onto Chihuahua, take HUAHUA off it, or swap HUAHUA for another
asset across chains.

## Table of contents
- [Where IBC stands (read first)](#where-ibc-stands-read-first)
- [Skip Go core concepts](#skip-go-core-concepts)
- [Option A: the Widget](#option-a-the-widget)
- [Option B: the API / SDK](#option-b-the-api--sdk)
- [Plain IBC transfer over the Osmosis channel](#plain-ibc-transfer-over-the-osmosis-channel)
- [Acquiring HUAHUA (funding a treasury or faucet)](#acquiring-huahua-funding-a-treasury-or-faucet)
- [Chihuahua-specific notes](#chihuahua-specific-notes)
- [Verifying a transfer landed](#verifying-a-transfer-landed)

## Where IBC stands (read first)

As of 2026-11-10, Chihuahua's **only live IBC path is Osmosis**: Chihuahua `channel-7`
↔ Osmosis `channel-113` (client recovered by proposal #102). Most other channels
still read `STATE_OPEN` but their light clients have expired, so transfers over them
fail. Everything cross-chain therefore goes **through Osmosis**:

| On Chihuahua | Comes from | Denom on Chihuahua |
|--------------|------------|--------------------|
| HUAHUA | native | `uhuahua` |
| USDC | Injective's USDC, via Osmosis | `ibc/2CAD00F0570FC6068204B0F4DB49B5752ABEC73B8604693C528B0D9A4417A4D1` |
| ATOM | via Osmosis | `ibc/B1C671DAA104B8D93C7E4F2C9E0BAD4FEEB7AD0FF39F0DE91B471CD92DB077B5` |
| OSMO | Osmosis | `ibc/FAC1BAAA6ECDCB88408A6EEEA13AD4736DA687F85ACD22B5BBD00D36754AC0FA` |

A token's Chihuahua denom is `ibc/` + SHA-256 of `transfer/channel-7/<its full path on
Osmosis>`, uppercase hex; resolve any `ibc/...` with
`GET /ibc/apps/transfer/v1/denoms/{hash}`. Noble USDC is being wound down by Circle,
so don't build on it. Check a client before relying on any other channel
(see [network.md → IBC status](network.md#ibc-status)).

## Skip Go core concepts

[Skip Go](https://docs.skip.build/go) routes tokens across chains by composing IBC
transfers and DEX swaps into one multi-hop route. It supports `chihuahua-1` and, in a
2026-11-10 check, returned a working route from OSMO on Osmosis to `uhuahua` on
Chihuahua (a swap on Osmosis, then IBC over channel-113).

The flow is always three phases:

1. **Route:** ask Skip for the best path from a source asset/chain to a destination
   asset/chain for an amount. It returns the operations and the expected output.
2. **Messages:** ask Skip to turn that route into ready-to-sign transactions, given
   the user's addresses on each chain in the path.
3. **Submit & track:** sign and broadcast each tx in order, then poll Skip's track
   endpoint until the funds arrive (multi-hop transfers settle asynchronously as
   packets relay).

Identifiers for Chihuahua: chain ID `chihuahua-1`, native denom `uhuahua` (6
decimals). HUAHUA on another chain is an IBC voucher (`ibc/<HASH>`), different per
destination and channel: let Skip resolve denoms.

## Option A: the Widget

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

The widget handles wallet connection, route discovery, signing each hop and progress
tracking. Check its current prop names against the docs: the config surface changes
between versions.

## Option B: the API / SDK

```bash
npm install @skip-go/client
```

Sketch of the route → messages → submit flow (confirm method names against the
current `@skip-go/client` docs; the SDK API is versioned):

```ts
import { SkipClient } from "@skip-go/client";

const skip = new SkipClient(/* options: endpoints, signers per chain */);

// 1. route: OSMO on Osmosis -> HUAHUA on Chihuahua
const route = await skip.route({
  amountIn: "1000000",                 // 1 OSMO (uosmo, 6dp)
  sourceAssetDenom: "uosmo",
  sourceAssetChainId: "osmosis-1",
  destAssetDenom: "uhuahua",
  destAssetChainId: "chihuahua-1",
});

// 2. the user's address on every chain the route touches
const userAddresses = route.requiredChainAddresses.map((chainId) => ({
  chainId,
  address: /* the user's bech32 address on that chain */,
}));

// 3. execute: the SDK signs and broadcasts each hop and tracks settlement
await skip.executeRoute({
  route,
  userAddresses,
  onTransactionTracked: (tx) => console.log("hop landed", tx),
});
```

The raw HTTP API answers too, without the SDK:

```bash
curl -s -X POST https://api.skip.build/v2/fungible/route -H 'content-type: application/json' \
  -d '{"amount_in":"1000000","source_asset_denom":"uosmo","source_asset_chain_id":"osmosis-1","dest_asset_denom":"uhuahua","dest_asset_chain_id":"chihuahua-1"}' \
  | jq '{amount_out, operations: [.operations[] | keys[0]]}'
```

Message building is `POST /v2/fungible/msgs`, plus a track endpoint; check
https://docs.skip.build/go/api-reference for the current schema.

## Plain IBC transfer over the Osmosis channel

No Skip needed for a straight move between the two chains:

```bash
# Chihuahua -> Osmosis: HUAHUA to an osmo1... address over channel-7
chihuahuad tx ibc-transfer transfer transfer channel-7 osmo1recipient... 1000000000uhuahua \
  --packet-timeout-timestamp 2700000000000 --from "$KEY" $TXFLAGS
# Osmosis -> Chihuahua: send over Osmosis channel-113 to a chihuahua1... address
```

`--packet-timeout-timestamp` is relative, in nanoseconds (here 45 minutes): relayers
can be slow, so don't use a short timeout. A timed-out transfer is refunded to the
sender.

## Acquiring HUAHUA (funding a treasury or faucet)

You have funds on another chain and need **HUAHUA on Chihuahua** to pay gas or seed an
app (on the testnet, just use the faucet; see
[network.md → Testnet](network.md#testnet-woofnet-6)):

1. **One-shot via Skip Go (recommended).** A route to `uhuahua` on `chihuahua-1` does
   the swap *and* the IBC delivery in one flow. Skip swaps on **Osmosis** (the
   HUAHUA/OSMO pool) and transfers the result over channel-113.
2. **Manual on Osmosis.** Swap for HUAHUA in the HUAHUA/OSMO pool (Osmosis app or
   `osmosisd`), then IBC it to your Chihuahua address. More steps, no dependency on
   Skip.

> **HUAHUA liquidity is thin.** A large buy moves the price hard. Split big
> acquisitions, set a slippage bound, and check the quote first. For trading within
> Chihuahua itself, use [Huahuaswap](ecosystem.md#huahuaswap-the-native-dex) or
> [Huahua P2P](p2p-agents.md).

## Chihuahua-specific notes

- **Gas on the Chihuahua hop is paid in HUAHUA**, at least 500 uhuahua per gas. A pure
  IBC receive doesn't need gas from the user, but a swap or contract call on arrival
  does: make sure the account holds some HUAHUA, or nobody can act on the funds.
- **Route availability follows the live channels.** Today that means Osmosis only.
  Query the route endpoint and handle "no route found" gracefully.
- **Always show expected output and slippage** before signing a multi-hop route.

## Verifying a transfer landed

A cross-chain transfer isn't done when the source tx commits: packets still need to
relay. Confirm arrival on Chihuahua by either:

- polling Skip's track endpoint (or the SDK's `onTransactionTracked`) until it reports
  success on the destination, or
- checking the destination balance directly:
  ```bash
  curl -s "https://api.chihuahua.wtf/cosmos/bank/v1beta1/balances/chihuahua1...recipient" | jq
  ```

Treat "source tx succeeded" as "in flight", not "delivered".
