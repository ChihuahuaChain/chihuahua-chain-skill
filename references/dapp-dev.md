# Building a Chihuahua dApp (CosmJS + wallets)

This guide covers the frontend/app path: connecting a browser wallet (Keplr / Huallet),
reading chain state, signing and broadcasting transactions, interacting with CosmWasm
contracts, and subscribing to live events — all from JavaScript/TypeScript with
**CosmJS**.

## Table of contents
- [Fastest start: scaffold a full dApp (create-interchain-app)](#fastest-start-scaffold-a-full-dapp-create-interchain-app)
- [Install](#install)
- [Create a wallet programmatically (bots/backends/faucets)](#create-a-wallet-programmatically-botsbackendsfaucets)
- [Add Chihuahua to the wallet (suggestChain)](#add-chihuahua-to-the-wallet-suggestchain)
- [Connect & get a signer](#connect--get-a-signer)
- [Read-only queries (no wallet)](#read-only-queries-no-wallet)
- [Send HUAHUA](#send-huahua)
- [Talk to a CosmWasm contract](#talk-to-a-cosmwasm-contract)
- [Live updates over WebSocket](#live-updates-over-websocket)
- [Amount handling (the #1 bug)](#amount-handling-the-1-bug)

## Fastest start: scaffold a full dApp (create-interchain-app)

If the goal is "a working Chihuahua web app, quickly" — not learning the plumbing —
don't wire it by hand. [create-interchain-app](https://github.com/hyperweb-io/create-interchain-app)
(CIA, by Hyperweb / formerly Cosmology) is the create-react-app of Cosmos: one command
scaffolds a **Next.js** app with multi-wallet connect (Keplr, Cosmostation,
Ledger, 20+ via [Interchain Kit](#managed-multi-wallet-connection-interchain-kit--cosmos-kit-30)),
signing (InterchainJS), and chain/asset data pulled straight from the
**Cosmos chain-registry**:

```bash
npx create-interchain-app
# or: npm init interchain-app  /  pnpm create interchain-app
```

**Why it just works for Chihuahua:** CIA reads the chain-registry, and Chihuahua is
registered as `chihuahua-1`, so the chain, its `uhuahua` asset, RPC/REST endpoints,
and wallet config come in without you hand-writing a `suggestChain` block. Point the
generated app at Chihuahua by selecting/adding `chihuahua` from the registry in its
config (e.g. `useChain("chihuahua")` with Interchain Kit). Example templates
(`stake-tokens`, `vote-proposal`, `ibc-asset-list`) give you working flows to adapt.

**When to use this vs. the rest of this guide:** CIA gets you a polished multi-wallet
**frontend** fast, on the Hyperweb stack (Interchain Kit + InterchainJS). The CosmJS
patterns below are the right call when you want a **lean dependency footprint**, a
**backend/bot/faucet** (no React), or **full control** over signing and clients — and
they're what you'll reach for to understand what CIA is doing under the hood. CIA is
beta; pin a version and skim its release notes before shipping.

## Install

```bash
npm install @cosmjs/stargate @cosmjs/cosmwasm-stargate @cosmjs/proto-signing @cosmjs/tendermint-rpc
# wallet types (optional, for TS): @keplr-wallet/types
```

These are the [CosmJS](https://github.com/cosmos/cosmjs) libraries — the standard
TypeScript toolkit for Cosmos chains. When you need an API detail this guide doesn't
cover (a client method signature, an Amino/Proto encoding edge case), the
[cosmjs repo](https://github.com/cosmos/cosmjs) and its package READMEs are the
reference.

Network constants (keep these in one module — see also
[`../assets/chain-info.json`](../assets/chain-info.json)):

```ts
export const CHAIN_ID = "chihuahua-1";
export const RPC = "https://rpc.chihuahua.wtf";
export const REST = "https://api.chihuahua.wtf";
export const DENOM = "uhuahua";       // base unit
export const DISPLAY = "HUAHUA";
export const DECIMALS = 6;
export const GAS_PRICE = "1250uhuahua";
export const PREFIX = "chihuahua";
```

## Create a wallet programmatically (bots/backends/faucets)

A browser dApp gets its signer from Keplr/Huallet (below). But a **backend** — a faucet,
a trading bot, a deploy script, an indexer that also writes — has no browser wallet.
Generate or load a key directly with CosmJS. The Chihuahua address prefix is
`chihuahua` and the coin type is `118`:

```ts
import { DirectSecp256k1HdWallet } from "@cosmjs/proto-signing";
import { SigningStargateClient, GasPrice } from "@cosmjs/stargate";

// Generate a brand-new wallet (24-word mnemonic). SAVE the mnemonic securely.
const wallet = await DirectSecp256k1HdWallet.generate(24, { prefix: "chihuahua" });
const [account] = await wallet.getAccounts();
console.log("address:", account.address);          // chihuahua1...
console.log("mnemonic:", wallet.mnemonic);          // store in a secret manager, NOT in code

// Later, load it back from the saved mnemonic:
const loaded = await DirectSecp256k1HdWallet.fromMnemonic(
  process.env.WALLET_MNEMONIC!, { prefix: "chihuahua" }
);

// Use it like any signer:
const client = await SigningStargateClient.connectWithSigner(RPC, loaded, {
  gasPrice: GasPrice.fromString(GAS_PRICE),
});
```

> **The mnemonic is the funds.** Anyone who reads it controls the account. Never log
> it in production, never commit it, never put it in client-side code. Load it from an
> environment variable or a secret manager (AWS Secrets Manager, Vault, etc.). For a
> CLI key instead of a programmatic one, use `chihuahuad keys add` — see
> [network.md](network.md#common-cli-recipes). The same mnemonic imports into both
> CosmJS and `chihuahuad keys add --recover`, since both derive at coin type 118.

## Add Chihuahua to the wallet (suggestChain)

A user's Keplr/Huallet may not know Chihuahua yet. Register it before connecting. The
full config object is in [`../assets/chain-info.json`](../assets/chain-info.json) —
import it and pass it straight in:

```ts
import chainInfo from "./chain-info.json";

async function ensureChain(wallet = window.keplr) {
  if (!wallet) throw new Error("No Cosmos wallet found (install Huallet or Keplr)");
  // experimentalSuggestChain is a no-op if the chain is already known
  await wallet.experimentalSuggestChain(chainInfo);
}
```

[Huallet](https://github.com/ChihuahuaChain/huallet), Chihuahua's own wallet, exposes the same API at
`window.huallet`, so writing against the Keplr interface works for both.

## Connect & get a signer

```ts
import { SigningStargateClient, GasPrice } from "@cosmjs/stargate";

async function connect(wallet = window.keplr) {
  await ensureChain(wallet);
  await wallet.enable(CHAIN_ID);
  const signer = wallet.getOfflineSignerAuto
    ? await wallet.getOfflineSignerAuto(CHAIN_ID)
    : wallet.getOfflineSigner(CHAIN_ID);
  const [account] = await signer.getAccounts();

  const client = await SigningStargateClient.connectWithSigner(RPC, signer, {
    gasPrice: GasPrice.fromString(GAS_PRICE),
  });
  return { client, address: account.address }; // address is chihuahua1...
}
```

### Managed multi-wallet connection (Interchain Kit / Cosmos Kit 3.0)

The `window.keplr` approach above is fine for one or two wallets, but a real app
usually wants a connect-modal, 20+ wallets, reconnection, and account state handled
for you. [Interchain Kit](https://github.com/hyperweb-io/interchain-kit) (by Hyperweb)
is exactly that — a universal wallet adapter for **React and Vue**, and it's the
successor to the widely-used **cosmos-kit** ("Cosmos Kit 3.0"). It pulls chain config
from the chain-registry, so Chihuahua (`chihuahua`) works without a hand-written
`suggestChain`, and it supports Keplr, Cosmostation, OKX, Ledger, WalletConnect,
and more.

```bash
npm install @interchain-kit/react @interchain-kit/core
```

The key thing for this guide: Interchain Kit **exposes an offline signer**, so it slots
in as a *replacement for the connection layer only* — you can still hand its signer to
the CosmJS clients shown above, or use it with InterchainJS (its native "CosmJS 2"
stack). Sketch:

```tsx
// wrap your app in <ChainProvider> (chains/assetLists from @chain-registry), then:
import { useChain } from "@interchain-kit/react";

const { address, getOfflineSigner, connect } = useChain("chihuahua");
// const signer = await getOfflineSigner();
// const client = await SigningStargateClient.connectWithSigner(RPC, signer,
//   { gasPrice: GasPrice.fromString(GAS_PRICE) });   // reuse everything below
```

This is also the wallet layer that [create-interchain-app](#fastest-start-scaffold-a-full-dapp-create-interchain-app)
scaffolds for you — reach for Interchain Kit directly when you're adding wallet
connection to an *existing* app rather than starting fresh. Some packages are beta;
pin versions. Confirm current hook/provider names against its docs, as the API evolves.

## Read-only queries (no wallet)

For dashboards and reads you don't need a signer — a plain client is lighter:

```ts
import { StargateClient } from "@cosmjs/stargate";

const client = await StargateClient.connect(RPC);
const balances = await client.getAllBalances("chihuahua1...");
// balances: [{ denom: "uhuahua", amount: "12345000" }]  -> 12.345 HUAHUA
```

## Send HUAHUA

`sendTokens` takes the amount in **uhuahua**. Convert from display units at the UI
boundary (see [Amount handling](#amount-handling-the-1-bug)):

```ts
const { client, address } = await connect();
const amount = [{ denom: DENOM, amount: "5000000" }]; // 5 HUAHUA
const res = await client.sendTokens(
  address, "chihuahua1recipient...", amount, "auto", "sent via dApp"
);
if (res.code !== 0) throw new Error(`tx failed: ${res.rawLog}`);
console.log("tx hash", res.transactionHash);
```

## Talk to a CosmWasm contract

```ts
import { SigningCosmWasmClient, CosmWasmClient } from "@cosmjs/cosmwasm-stargate";

// read-only query
const cw = await CosmWasmClient.connect(RPC);
const state = await cw.queryContractSmart(CONTRACT_ADDR, { get_count: {} });

// execute (needs a signer)
const { client, address } = await connectCw(); // SigningCosmWasmClient, same pattern as connect()
const result = await client.execute(
  address, CONTRACT_ADDR, { increment: {} }, "auto",
  undefined, /* optional funds: */ [{ denom: DENOM, amount: "1000000" }]
);
```

`connectCw` is identical to `connect()` but builds a `SigningCosmWasmClient`:

```ts
const client = await SigningCosmWasmClient.connectWithSigner(RPC, signer, {
  gasPrice: GasPrice.fromString(GAS_PRICE),
});
```

For contract deployment from JS (`upload` + `instantiate`), see the CosmWasm path in
[smart-contracts.md](smart-contracts.md) — but most apps deploy with the CLI and only
*interact* from the frontend.

## Live updates over WebSocket

Subscribe to chain events without polling. CometBFT WS lives at `/websocket` on any
RPC node (see [network.md](network.md#websocket-events--subscriptions)):

```ts
import { Tendermint37Client, WebsocketClient } from "@cosmjs/tendermint-rpc";

const ws = new WebsocketClient("wss://rpc.chihuahua.wtf/websocket");
const tm = await Tendermint37Client.create(ws);

// new blocks
const blockStream = tm.subscribeNewBlock();
const sub = blockStream.subscribe({
  next: (b) => console.log("height", b.header.height),
  error: (e) => console.error("ws closed", e),
});

// watch incoming transfers to an address
const txStream = tm.subscribeTx(
  `transfer.recipient='chihuahua1youraddr...'`
);
```

WS subscriptions are best-effort: handle the `error`/close callback and reconnect,
and treat a missed event as possible — reconcile against a REST/`getAllBalances`
poll on reconnect so your UI can't silently miss a deposit. (Use
`Tendermint34Client` instead of `37` if you hit a version-handshake error against an
older node.)

## Amount handling (the #1 bug)

Every on-chain amount is an integer string of `uhuahua`. The display value the user
sees is `amount / 1e6`. Convert explicitly at the boundary and never do float math on
balances:

```ts
import { Decimal } from "@cosmjs/math";

export const toMicro = (huahua: string) =>
  Decimal.fromUserInput(huahua, DECIMALS).atomics;            // "5" -> "5000000"
export const toDisplay = (uhuahua: string) =>
  Decimal.fromAtomics(uhuahua, DECIMALS).toString();          // "5000000" -> "5"
```

A dropped or extra zero here is a 10x funds error and an extra six is a 1,000,000x
error — this is where dApps lose money, so wrap it once and reuse it everywhere.
