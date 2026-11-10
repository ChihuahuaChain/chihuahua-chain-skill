# Huahua P2P: trading from code and as an AI agent (x402)

[Huahua P2P](https://p2p.chihuahua.wtf) is Chihuahua's paw-to-paw (peer-to-peer)
exchange: a maker escrows one token and names the token they want; anyone fills the
offer and both sides move in the same transaction, in full or not at all. There is no
pool and no price oracle: makers set prices.

- [Facts](#facts)
- [The agent API (x402)](#the-agent-api-x402)
- [Paying with plain CosmJS](#paying-with-plain-cosmjs)
- [Calling the contract directly](#calling-the-contract-directly)
- [Safety rules for agents](#safety-rules-for-agents)

## Facts

|  |  |
|--|--|
| Contract (mainnet) | `chihuahua1h9etpw4a3k0dtzktdzznk7rhnkxcg48datcns47fz42hpehfesvqu0jh8x` (no wasm admin: it cannot be migrated) |
| Site | https://p2p.chihuahua.wtf |
| Agent API | https://p2p.chihuahua.wtf/api (x402 v2) |
| LLM summary | https://p2p.chihuahua.wtf/llms.txt |
| Trading fee | 0.1% when HUAHUA is one side, 0.3% otherwise; half of every HUAHUA fee is burned |
| Partial fills | an offer may allow buying a part (`partial`, `min_fill`) |
| Listing | any token for 100 USDC or 20M HUAHUA; Huahuaswap launchpad tokens that completed their curve list free |
| Gas per action | create ~150, fill ~210, cancel ~135 HUAHUA (at 500 uhuahua per gas) |

## The agent API (x402)

Reads are free JSON; the three trades are [x402](https://github.com/x402-foundation/x402)
v2 resources:

| Request |  |
|---------|--|
| `GET /api` | network, contract, endpoints |
| `GET /api/tokens` | tradable tokens (denom, symbol, decimals) and fees |
| `GET /api/offers?give=&want=&maker=&limit=&start_before=` | open offers (or every offer of `maker`), base units, `price` = want per give |
| `GET /api/offers/{id}` | one offer |
| `GET /api/offers/{id}/quote?amount=` | what a fill of `amount` (give token, base units) pays and receives |
| `POST /api/offers/{id}/fill?amount=` | **x402**: buy the offer, or part of a partial one |
| `POST /api/offers` | **x402**: make an offer; JSON `{give:{denom,amount}, want:{denom,amount}, taker?, expires_at?, partial?, min_fill?}` |
| `POST /api/offers/{id}/cancel` | **x402, amount 0**: the maker takes it down |

The x402 handshake:

1. Send the request. The answer is **402** with a `PAYMENT-REQUIRED` header (base64
   JSON, also the body). `accepts[0]` is scheme `exact` on network
   `cosmos:chihuahua-1`, with `extra.assetTransferMethod: "cosmwasm-execute"`. It names
   one contract execution: `payTo` (the contract), `extra.msg` (the exact execute
   message), `amount` + `asset` (the coin to attach; none when `amount` is `"0"`), and
   `extra.minGasPrice`.
2. Check the terms against your own policy (right contract, right message, a price
   you accept).
3. Sign **one** `MsgExecuteContract` with `sender` = your address, `contract` =
   `payTo`, `msg` = `extra.msg`, `funds` = the coin, paying your own fee.
4. Send the same request again with header
   `PAYMENT-SIGNATURE: base64(JSON {x402Version: 2, accepted: <that requirement>, payload: {transaction: <base64 TxRaw>}})`.
5. The API verifies (message, funds, signer, fee, sequence, signature, simulation),
   broadcasts, waits for the block, and answers **200** with the outcome and a
   `PAYMENT-RESPONSE` header (`success`, `transaction`). A refusal is a new 402 whose
   `error` says why.

The API holds no key and no coin: it can only forward what you signed, and the
contract enforces the price. x402 has no official Cosmos scheme yet; this one follows
the shape of `exact` on Sui (the payer signs a complete transaction, the facilitator
checks and broadcasts it). `GET /api/x402/supported` lists it.

## Paying with plain CosmJS

A complete payer (Node 18+, `npm i @cosmjs/proto-signing@^0.39 @cosmjs/amino@^0.39 @cosmjs/encoding@^0.39 cosmjs-types`),
tested end to end against the API on 2026-11-10:

```js
import { DirectSecp256k1HdWallet, Registry, encodePubkey, makeAuthInfoBytes, makeSignDoc } from "@cosmjs/proto-signing";
import { encodeSecp256k1Pubkey } from "@cosmjs/amino";
import { fromBase64, toBase64, toUtf8 } from "@cosmjs/encoding";
import { MsgExecuteContract } from "cosmjs-types/cosmwasm/wasm/v1/tx";
import { TxRaw } from "cosmjs-types/cosmos/tx/v1beta1/tx";
import { SignMode } from "cosmjs-types/cosmos/tx/signing/v1beta1/signing";

const API = "https://p2p.chihuahua.wtf/api";
const REST = "https://api.chihuahua.wtf";
const P2P = "chihuahua1h9etpw4a3k0dtzktdzznk7rhnkxcg48datcns47fz42hpehfesvqu0jh8x";
const EXEC = "/cosmwasm.wasm.v1.MsgExecuteContract";
const registry = new Registry([[EXEC, MsgExecuteContract]]);
const toHeader = (o) => Buffer.from(JSON.stringify(o)).toString("base64");
const fromHeader = (s) => JSON.parse(Buffer.from(s, "base64").toString());

async function rest(path, body) {
  const r = await fetch(REST + path, body ? { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body) } : {});
  const j = await r.json();
  if (!r.ok) throw new Error(j.message || `HTTP ${r.status}`);
  return j;
}

// Sign the one execution a 402 asks for. Returns the PAYMENT-SIGNATURE value.
async function paymentFor(req, wallet) {
  const [acct] = await wallet.getAccounts();
  const { account } = await rest(`/cosmos/auth/v1beta1/accounts/${acct.address}`);
  const accountNumber = BigInt(account.account_number), sequence = BigInt(account.sequence);
  const funds = req.amount === "0" ? [] : [{ denom: req.asset, amount: req.amount }];
  const msg = { typeUrl: EXEC, value: MsgExecuteContract.fromPartial({
    sender: acct.address, contract: req.payTo, msg: toUtf8(JSON.stringify(req.extra.msg)), funds }) };
  const bodyBytes = registry.encode({ typeUrl: "/cosmos.tx.v1beta1.TxBody", value: { messages: [msg] } });
  const pubkey = encodePubkey(encodeSecp256k1Pubkey(acct.pubkey));
  const tx = (authInfoBytes, sig) => toBase64(TxRaw.encode(TxRaw.fromPartial({ bodyBytes, authInfoBytes, signatures: [sig] })).finish());

  // Simulate (the contract refuses here, before anything is signed), then pad the gas.
  const simAuth = makeAuthInfoBytes([{ pubkey, sequence }], [], 0, undefined, undefined, SignMode.SIGN_MODE_DIRECT);
  const sim = await rest("/cosmos/tx/v1beta1/simulate", { tx_bytes: tx(simAuth, new Uint8Array()) });
  const gas = Math.ceil(Number(sim.gas_info.gas_used) * 1.6) + 30000;
  const fee = [{ denom: "uhuahua", amount: String(Math.ceil(gas * Number(req.extra.minGasPrice.amount))) }];

  const authInfoBytes = makeAuthInfoBytes([{ pubkey, sequence }], fee, gas, undefined, undefined, SignMode.SIGN_MODE_DIRECT);
  const { signed, signature } = await wallet.signDirect(acct.address, makeSignDoc(bodyBytes, authInfoBytes, req.extra.chainId, accountNumber));
  const signedTx = toBase64(TxRaw.encode(TxRaw.fromPartial({
    bodyBytes: signed.bodyBytes, authInfoBytes: signed.authInfoBytes, signatures: [fromBase64(signature.signature)] })).finish());
  return toHeader({ x402Version: 2, accepted: req, payload: { transaction: signedTx } });
}

// fetch with x402: on a 402, check the terms with `approve`, sign, send again.
export async function payFetch(url, init, wallet, approve) {
  const first = await fetch(url, init);
  if (first.status !== 402) return first;
  const req = fromHeader(first.headers.get("payment-required")).accepts[0];
  if (!approve(req)) throw new Error(`refused: ${req.amount} ${req.asset} for ${JSON.stringify(req.extra.msg)}`);
  const headers = { ...(init && init.headers), "PAYMENT-SIGNATURE": await paymentFor(req, wallet) };
  return fetch(url, { ...init, headers });
}

// Example: buy offer ID whole, paying at most 50 HUAHUA, only on the P2P contract.
const ID = Number(process.argv[2]);
const wallet = await DirectSecp256k1HdWallet.fromMnemonic(process.env.MNEMONIC, { prefix: "chihuahua" });
const res = await payFetch(`${API}/offers/${ID}/fill`, { method: "POST" }, wallet, (req) =>
  req.payTo === P2P && req.network === "cosmos:chihuahua-1" &&
  JSON.stringify(req.extra.msg) === JSON.stringify({ fill: { id: ID } }) &&
  req.asset === "uhuahua" && BigInt(req.amount) <= 50_000_000n);
console.log(res.status, fromHeader(res.headers.get("payment-response") || "e30="), await res.json());
```

To make an offer, `POST` the JSON body to `/api/offers` with the same `payFetch`; to
cancel one of your offers, `POST /api/offers/{id}/cancel` (it attaches no coin, only
the network fee is paid). `expires_at` must be absolute unix seconds, so that the
retry signs exactly the message the 402 named.

## Calling the contract directly

The API is a convenience; the contract is the source of truth and any CosmWasm client
can use it (see [smart-contracts.md](smart-contracts.md#step-5-execute--query)):

| Message |  |
|---------|--|
| `{"create":{"want":{"denom","amount"},"taker":null,"expires_at":null,"partial":false,"min_fill":null}}` + funds = the coin you give | make an offer |
| `{"fill":{"id":7,"amount":null}}` + funds = exactly the quoted price | buy it (`amount` = part of a partial offer, in the give token) |
| `{"cancel":{"id":7}}` | the maker takes it down; the escrow comes back |
| `{"expire":{"ids":[7]}}` | anyone returns expired offers' escrow to their makers |

Queries: `{"offer":{"id":7}}`, `{"open_offers":{"start_before":null,"limit":50}}`,
`{"offers_by_maker":{"maker":"chihuahua1...","start_before":null,"limit":50}}`,
`{"fill_quote":{"id":7,"amount":null}}`, `{"config":{}}`, `{"stats":{}}`. A fill must
attach **exactly** the price from `fill_quote`, in one coin; anything else is refused.

## Safety rules for agents

- **A dedicated wallet** holding only what the agent may trade, plus HUAHUA for gas.
  A new address must first *receive* funds before it exists on chain and can sign.
- **Never put the mnemonic in the model's context**: load it from a file or a secret
  store in the process that signs.
- **Check every 402 before signing:** `payTo` is the P2P contract, `network` is
  `cosmos:chihuahua-1`, `extra.msg` is the action you asked for, and the amount is
  within a cap you set per token. Read `GET /api/offers/{id}/quote` first and compare
  the price with the market (Huahuaswap reserves, Osmosis, CoinGecko): makers set
  prices freely.
- **Tokenfactory tokens can have powerful admins.** A `factory/...` denom's admin can
  force-transfer or burn it from any account, escrow included. Check
  `chihuahuad query tokenfactory denom-authority-metadata <denom>` before buying an
  unfamiliar token.
- **Fees are on top of the price:** each action costs ~130 to 250 HUAHUA of gas.
