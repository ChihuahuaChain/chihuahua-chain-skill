# Building a Chihuahua dApp (CosmJS + wallets)

This guide covers the frontend/app path: connecting a browser wallet (Keplr /
Huallet), reading chain state, signing and broadcasting transactions, interacting with
CosmWasm contracts, and subscribing to live events, all from JavaScript/TypeScript
with **CosmJS**. For bots and agents that trade, also see
[p2p-agents.md](p2p-agents.md).

## Table of contents
- [What changed with v10 (read this first)](#what-changed-with-v10-read-this-first)
- [Fastest start: scaffold a full dApp (create-interchain-app)](#fastest-start-scaffold-a-full-dapp-create-interchain-app)
- [Install](#install)
- [Create a wallet programmatically (bots/backends/faucets)](#create-a-wallet-programmatically-botsbackendsfaucets)
- [Add Chihuahua to the wallet (suggestChain)](#add-chihuahua-to-the-wallet-suggestchain)
- [Connect & get a signer](#connect--get-a-signer)
- [Gas and fees](#gas-and-fees)
- [Read-only queries (no wallet)](#read-only-queries-no-wallet)
- [Send HUAHUA](#send-huahua)
- [Talk to a CosmWasm contract](#talk-to-a-cosmwasm-contract)
- [Live updates over WebSocket](#live-updates-over-websocket)
- [Amount handling (the #1 bug)](#amount-handling-the-1-bug)

## What changed with v10 (read this first)

Code that worked on Chihuahua before October 2026 can fail now. Checked against
v10.0.1 on 2026-11-10:

- **CosmJS >= 0.39 is required.** Account numbers on Cosmos SDK v0.54 can exceed
  2^53; older CosmJS cannot sign for those accounts.
- **Gas price: at least 500 uhuahua per gas,** enforced in consensus. Anything lower
  is rejected as `insufficient fee`. The cosmos chain-registry still shows
  `fixed_min_gas_price: 0` (and a v7 binary): don't take the floor from it.
- **Don't use `"auto"` fees.** CosmJS's `"auto"` is simulation × 1.4, and a measured
  bank send used 41% more gas than simulated, so it ran out of gas and still paid the
  fee. Use simulation × 1.6 + 30,000 ([Gas and fees](#gas-and-fees)).
- **CometBFT v0.39.** `StargateClient`, `CosmWasmClient` and
  `SigningStargateClient` work over RPC with CosmJS 0.39 (queries, simulate,
  broadcast); for a raw CometBFT client use `connectComet` (or `Comet38Client`), not
  `Tendermint37Client`. **CosmJS WebSocket subscriptions do not deliver events** from
  CometBFT v0.39: subscribe with a plain WebSocket instead
  ([Live updates](#live-updates-over-websocket)). The REST API is an equally valid
  path for queries, simulate and broadcast.

## Fastest start: scaffold a full dApp (create-interchain-app)

If the goal is "a working Chihuahua web app, quickly", don't wire it by hand.
[create-interchain-app](https://github.com/hyperweb-io/create-interchain-app)
(CIA, by Hyperweb) scaffolds a **Next.js** app with multi-wallet connect (Keplr,
Cosmostation, Ledger and more via [Interchain Kit](#managed-multi-wallet-connection-interchain-kit)),
signing (InterchainJS), and chain/asset data pulled from the **Cosmos
chain-registry**:

```bash
npx create-interchain-app
# or: npm init interchain-app  /  pnpm create interchain-app
```

CIA reads the chain-registry, where Chihuahua is registered as `chihuahua-1`, so the
chain, its `uhuahua` asset and endpoints come in without a hand-written
`suggestChain` block. Two corrections the registry needs today: set the gas price to
at least `500uhuahua` and pad gas by 1.6 (see [What changed](#what-changed-with-v10-read-this-first)).
Example templates (`stake-tokens`, `vote-proposal`, `ibc-asset-list`) give you working
flows to adapt.

**When to use this vs. the rest of this guide:** CIA gets you a polished multi-wallet
**frontend** fast, on the Hyperweb stack. The CosmJS patterns below are the right call
for a **lean dependency footprint**, a **backend/bot/faucet** (no React), or **full
control** over signing. CIA is beta: pin a version and skim its release notes.

## Install

```bash
npm install @cosmjs/stargate@^0.39 @cosmjs/cosmwasm-stargate@^0.39 @cosmjs/proto-signing@^0.39 @cosmjs/tendermint-rpc@^0.39
# wallet types (optional, for TS): @keplr-wallet/types
```

These are the [CosmJS](https://github.com/cosmos/cosmjs) libraries, the standard
TypeScript toolkit for Cosmos chains. When you need an API detail this guide doesn't
cover, the cosmjs repo and its package READMEs are the reference.

Network constants (keep these in one module; see also
[`../assets/chain-info.json`](../assets/chain-info.json)):

```ts
export const CHAIN_ID = "chihuahua-1";            // "woofnet-6" on the testnet
export const RPC = "https://rpc.chihuahua.wtf";   // https://testnet-rpc.chihuahua.wtf
export const REST = "https://api.chihuahua.wtf";  // https://testnet-api.chihuahua.wtf
export const DENOM = "uhuahua";       // base unit
export const DISPLAY = "HUAHUA";
export const DECIMALS = 6;
export const GAS_PRICE = "500uhuahua"; // the consensus minimum; read it live, see below
export const PREFIX = "chihuahua";
```

## Create a wallet programmatically (bots/backends/faucets)

A browser dApp gets its signer from Keplr/Huallet (below). A **backend** (a faucet, a
trading bot, a deploy script, an AI agent) has no browser wallet: generate or load a
key directly with CosmJS. The address prefix is `chihuahua` and the coin type `118`:

```ts
import { DirectSecp256k1HdWallet } from "@cosmjs/proto-signing";
import { SigningStargateClient, GasPrice } from "@cosmjs/stargate";

// Generate a brand-new wallet (24-word mnemonic). SAVE the mnemonic securely.
const wallet = await DirectSecp256k1HdWallet.generate(24, { prefix: "chihuahua" });
const [account] = await wallet.getAccounts();
console.log("address:", account.address);          // chihuahua1...
// wallet.mnemonic: write it to a secret store or a file only the process user can
// read. Never log it, and never pass it through an AI agent's context.

// Later, load it back from the saved mnemonic:
const loaded = await DirectSecp256k1HdWallet.fromMnemonic(
  process.env.WALLET_MNEMONIC!, { prefix: "chihuahua" }
);

const client = await SigningStargateClient.connectWithSigner(RPC, loaded, {
  gasPrice: GasPrice.fromString(GAS_PRICE),
});
```

> **The mnemonic is the funds.** Anyone who reads it controls the account. Load it
> from an environment variable or a secret manager. The same mnemonic imports into
> CosmJS, Keplr, Huallet and `chihuahuad keys add --recover`, since all derive at coin
> type 118.

A new address does not exist on chain until it **receives** something, and it needs
HUAHUA for fees before it can sign anything. On the testnet, claim from the faucet
(see [network.md → Testnet](network.md#testnet-woofnet-6)).

## Add Chihuahua to the wallet (suggestChain)

A user's Keplr/Huallet may not know Chihuahua yet. Register it before connecting. The
full config object is in [`../assets/chain-info.json`](../assets/chain-info.json)
(gas price steps 500 / 750 / 1000 uhuahua):

```ts
import chainInfo from "./chain-info.json";

async function ensureChain(wallet = window.keplr) {
  if (!wallet) throw new Error("No Cosmos wallet found (install Huallet or Keplr)");
  await wallet.experimentalSuggestChain(chainInfo);   // no-op if already known
}
```

[Huallet](https://github.com/ChihuahuaChain/huallet), Chihuahua's own wallet
(Chrome, Firefox and Android), exposes the same API at `window.huallet`, so writing
against the Keplr interface works for both. For the testnet, users can add woofnet-6
from https://keplr.chihuahua.wtf/testnet.html.

## Connect & get a signer

Always use `getOfflineSignerAuto`: it returns an Amino signer for Ledger accounts
(which cannot sign Direct) and a Direct signer otherwise.

```ts
import { SigningStargateClient, GasPrice } from "@cosmjs/stargate";

async function connect(wallet = window.keplr) {
  await ensureChain(wallet);
  await wallet.enable(CHAIN_ID);
  const signer = await wallet.getOfflineSignerAuto(CHAIN_ID);
  const [account] = await signer.getAccounts();

  const client = await SigningStargateClient.connectWithSigner(RPC, signer, {
    gasPrice: GasPrice.fromString(GAS_PRICE),
  });
  return { client, address: account.address }; // address is chihuahua1...
}
```

### Managed multi-wallet connection (Interchain Kit)

The `window.keplr` approach is fine for one or two wallets; a real app usually wants a
connect modal, many wallets, reconnection, and account state handled for you.
[Interchain Kit](https://github.com/hyperweb-io/interchain-kit) (by Hyperweb) is a
universal wallet adapter for **React and Vue**, the successor of cosmos-kit. It pulls
chain config from the chain-registry and supports Keplr, Cosmostation, OKX, Ledger,
WalletConnect and more.

```bash
npm install @interchain-kit/react @interchain-kit/core
```

It **exposes an offline signer**, so it replaces only the connection layer: hand its
signer to the CosmJS clients shown here.

```tsx
// wrap your app in <ChainProvider> (chains/assetLists from @chain-registry), then:
import { useChain } from "@interchain-kit/react";

const { address, getOfflineSigner, connect } = useChain("chihuahua");
// const signer = await getOfflineSigner();
// const client = await SigningStargateClient.connectWithSigner(RPC, signer,
//   { gasPrice: GasPrice.fromString(GAS_PRICE) });   // reuse everything below
```

Some packages are beta: pin versions and confirm hook/provider names against its docs.

## Gas and fees

Read the consensus minimum live (governance can change it), simulate, pad, and pass an
explicit fee:

```ts
import { calculateFee, GasPrice } from "@cosmjs/stargate";

export async function minGasPrice(): Promise<GasPrice> {
  const { params } = await (await fetch(`${REST}/chihuahua/feeburn/params`)).json();
  const min = params.min_gas_prices?.find((c: { denom: string }) => c.denom === DENOM);
  return GasPrice.fromString(`${min ? Number(min.amount) : 500}${DENOM}`);
}

export async function feeFor(client, address: string, msgs, memo = "") {
  const simulated = await client.simulate(address, msgs, memo);
  return calculateFee(Math.ceil(simulated * 1.6) + 30_000, await minGasPrice());
}

// usage: await client.signAndBroadcast(address, msgs, await feeFor(client, address, msgs));
```

The fee is the gas limit times the price; a contract call typically costs 130 to 250
HUAHUA, a send 40 to 60. Show it to the user before they sign.

## Read-only queries (no wallet)

For dashboards and reads you don't need a signer:

```ts
import { StargateClient } from "@cosmjs/stargate";

const client = await StargateClient.connect(RPC);
const balances = await client.getAllBalances("chihuahua1...");
// balances: [{ denom: "uhuahua", amount: "12345000" }]  -> 12.345 HUAHUA
```

Or plain REST, with no dependency at all:
`fetch(`${REST}/cosmos/bank/v1beta1/balances/${address}`)`.

## Send HUAHUA

Amounts are in **uhuahua**. Convert from display units at the UI boundary (see
[Amount handling](#amount-handling-the-1-bug)):

```ts
const { client, address } = await connect();
const msgs = [{
  typeUrl: "/cosmos.bank.v1beta1.MsgSend",
  value: { fromAddress: address, toAddress: "chihuahua1recipient...", amount: [{ denom: DENOM, amount: "5000000" }] }, // 5 HUAHUA
}];
const res = await client.signAndBroadcast(address, msgs, await feeFor(client, address, msgs), "sent via dApp");
if (res.code !== 0) throw new Error(`tx failed: ${res.rawLog}`);
console.log("tx", `https://explorer.chihuahua.wtf/tx/${res.transactionHash}`);
```

## Talk to a CosmWasm contract

```ts
import { SigningCosmWasmClient, CosmWasmClient } from "@cosmjs/cosmwasm-stargate";
import { toUtf8 } from "@cosmjs/encoding";

// read-only query
const cw = await CosmWasmClient.connect(RPC);
const state = await cw.queryContractSmart(CONTRACT_ADDR, { get_count: {} });

// execute (needs a signer): same pattern as connect(), with SigningCosmWasmClient
const client = await SigningCosmWasmClient.connectWithSigner(RPC, signer, { gasPrice: await minGasPrice() });
const msgs = [{
  typeUrl: "/cosmwasm.wasm.v1.MsgExecuteContract",
  value: { sender: address, contract: CONTRACT_ADDR, msg: toUtf8(JSON.stringify({ increment: {} })),
           funds: [{ denom: DENOM, amount: "1000000" }] },   // optional funds
}];
const res = await client.signAndBroadcast(address, msgs, await feeFor(client, address, msgs));
```

For contract deployment from JS (`upload` + `instantiate`), see the CosmWasm path in
[smart-contracts.md](smart-contracts.md); most apps deploy with the CLI and only
*interact* from the frontend.

## Live updates over WebSocket

Subscribe to chain events without polling. CometBFT WS lives at `/websocket` on any
RPC node (see [network.md](network.md#websocket-events--subscriptions)). CosmJS 0.39
subscriptions (`Comet38Client.subscribeNewBlock`) open but receive nothing from
CometBFT v0.39, so speak the JSON-RPC protocol directly; it is a few lines and works
in browsers and Node 22+:

```ts
function subscribe(query: string, onEvent: (value: any) => void) {
  const ws = new WebSocket("wss://rpc.chihuahua.wtf/websocket");
  ws.onopen = () => ws.send(JSON.stringify({ jsonrpc: "2.0", method: "subscribe", id: 1, params: { query } }));
  ws.onmessage = (m) => {
    const d = JSON.parse(m.data);
    if (d.result?.data) onEvent(d.result.data.value);   // the first reply is an empty ack
  };
  return ws;   // ws.close() to stop; reconnect on ws.onclose
}

// new blocks
subscribe("tm.event='NewBlock'", (v) => console.log("height", v.block.header.height));
// incoming transfers to an address
subscribe("tm.event='Tx' AND transfer.recipient='chihuahua1youraddr...'", (v) => console.log(v.TxResult));
```

WS subscriptions are best-effort: reconnect on close and reconcile against a balance
poll on reconnect, so your UI can't silently miss a deposit.

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
error: this is where dApps lose money, so wrap it once and reuse it everywhere. Other
tokens have their own decimals (read them from bank metadata,
`/cosmos/bank/v1beta1/denoms_metadata_by_query_string?denom=<denom>`, taking the
largest exponent).
