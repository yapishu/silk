# silk

`%silk` is a decentralized marketplace protocol built on top of the [skein](https://github.com/yapishu/skein) mixnet. It separates transport identity, market pseudonyms, and payment identity, and it routes all peer traffic over `%skein` rather than direct ship-to-ship pokes.

## Current Status

Implemented today:

- pseudonyms with labels, local ed25519 keypairs, and wallet strings
- listing publication, retraction, and per-listing inventory tracking
- marketplace peer management and catalog sync over `%skein`
- automatic peer discovery via the `%silk-market` channel on `%skein`
- direct messages, offers, accepts, rejects, invoices, payment proofs, fulfillment messages, completion, disputes, verdict messages, cancel, and feedback messages
- per-thread hash chains plus `sync-thread` / `sync-thread-response` reconciliation messages
- unique per-transaction thread ids
- direct-settlement invoices with per-transaction Zenith addresses generated through the local `%zenith` agent
- `pay-invoice` via a local Zenith account, with polling that auto-submits payment proof once the invoice address verifies
- `%khan`-based balance verification against invoice addresses
- optional 2-of-3 escrow multisigs with moderator selection, per-thread secp256k1 keys, multisig address derivation, signature collection, raw tx assembly, rebroadcast, broadcast via `%silk-zenith`, and post-broadcast confirmation polling
- moderator registration, gossip, local moderator key storage, and `/my-escrows` moderator view
- `%silk-market` as a wired-in order state machine sidecar
- `%silk-zenith` escrow account-number / sequence lookup and raw escrow tx broadcast bridge
- ack-driven resend with bounded retry and exponential backoff for critical messages
- HTTP JSON API for the frontend
- a browser UI for identities, listings, threads, orders, reputation, moderators, and network management
- local reputation storage and simple aggregate scoring via `%silk-rep`
- `tools/verify-multisig/` to cross-check multisig address derivation against the Cosmos SDK

Still not finished:

- `%silk-market` validates transitions but is not yet the authoritative gate for mutations
- `%silk-zenith` contains address-pool and payment-record machinery, but the main invoice and wallet-send path still goes through `%silk-core` talking directly to `%zenith`
- inbound attestations are imported without signature verification
- dispute filing exists, but moderator verdict handling is incomplete and `%split` is not a real split payout yet
- counter-offers, `%ping`, `%pong`, and negotiation-key material are typed but not part of the main UI/API flow

## System Split

Silk is intentionally split across two desks:

- `../skein`: content-agnostic transport, routing, relay discovery, and delivery
- `%silk`: marketplace semantics, pseudonyms, listings, negotiation, payment coordination, moderators, escrow, and reputation

Silk also separates three identities:

- `ship`: the Urbit transport identity used by `%skein`
- `pseudonym`: the market-facing `nym-id` with its own keypair
- `wallet` / payment address: direct invoice addresses or escrow multisig addresses on Zenith, decoupled from both ship and pseudonym

## Agents

### `%silk-core`

`desk/app/silk-core.hoon` (state-8) is the live hub.

It owns:

- pseudonyms and their local ed25519 keypairs
- listings and per-listing inventory counts
- peer ships
- route mappings from `nym-id` to `%skein` endpoints
- thread state and message logs
- local attestation cache
- payment verification snapshots
- moderator directory and local moderator private keys
- per-thread escrow configs, signer keys, collected signatures, and assembled tx hex
- pending message acks and resend state
- the JSON API at `/apps/silk/api`
- the `/events` fact stream used by the UI

For direct invoices, silk-core generates a fresh private key, pokes `%zenith %add-account`, scries the derived bech32 address back, and includes that address in the invoice sent to the buyer. `pay-invoice` sends through the local `%zenith` agent and then polls the invoice address until the balance verifies.

For escrowed orders, silk-core derives the 2-of-3 multisig address, auto-invoices the buyer to that address, collects release / refund signatures, assembles the raw transaction once 2 signatures are present locally, and asks `%silk-zenith` to broadcast it and query account metadata needed for signing.

silk-core also notifies `%silk-market` of order-state transitions via advance cards. Market validates the transition and emits invalid-transition events, but silk-core still mutates its own thread state first.

### `%silk-market`

`desk/app/silk-market.hoon` (state-1) implements the order state machine:

- `offered -> accepted -> escrow-proposed -> escrow-agreed -> invoiced -> paid -> escrowed -> fulfilled -> completed`
- dispute branches to `disputed -> resolved`, plus cancellation
- explicit invalid-transition reporting and same-state no-ops
- escrow records on `%set-escrow`
- completion-triggered attestation issuance into `%silk-rep`

It is wired into the live flow as a sidecar. silk-core creates and advances orders there, but market is not yet the authoritative source of truth.

### `%silk-rep`

`desk/app/silk-rep.hoon` (state-0) stores issued and imported attestations and computes a simple average score per subject nym.

This agent is live:

- `%silk-core` imports inbound attestations into `%silk-rep`
- locally authored feedback is issued into `%silk-rep`
- completion of an order in `%silk-market` triggers attestation issuance

The API-facing reputation view is still assembled in `%silk-core`.

### `%silk-zenith`

`desk/app/silk-zenith.hoon` (state-0) tracks:

- wallet mode (`%local` or `%external`)
- optional address pools per seller nym
- payment records per invoice
- escrow tx broadcast requests
- escrow account-number / sequence lookups

Today, `%silk-zenith` is live mainly in the escrow path and as an auxiliary wallet/data bridge. The main direct invoice-address generation and wallet-send flow still lives in `%silk-core` talking to `%zenith` directly.

## Protocol Surface

Core types live in `desk/sur/silk.hoon`.

### Identity, Reputation, And Moderator Types

- `pseudonym`: id, label, pubkey, wallet, created-at
- `nym-keypair`: local pub + sec signing keys
- `attestation`: signed claim with kind, score, note
- `nym-route`: maps a nym-id to a `%skein` endpoint
- `moderator-profile`: moderator nym, secp256k1 pubkey, fee metadata, claimed stake metadata, description

### Marketplace, Thread, And Escrow Types

- `listing`: id, seller, title, description, price, currency, created-at, optional expiry
- `offer`: thread-id, listing-id, buyer, seller, amount, currency, note
- `accept` / `reject`
- `invoice`: id, thread-id, offer-id, seller, amount, currency, pay-address, expires-at
- `payment-proof`: thread-id, invoice-id, tx-hash, paid-at
- `fulfillment`: thread-id, offer-id, note, opaque payload
- `dispute` / `verdict`
- `escrow-config`: buyer / seller / moderator pubkeys, multisig address, wallets, timeout, fee metadata, account number, sequence
- `escrow-st`: `proposed`, `agreed`, `funded`, `releasing`, `released`, `refunding`, `refunded`, `confirmed`, `disputed`, `resolved`
- `silk-thread`: id, listing-id, buyer, seller, status, messages, chain hash, timestamps

### Message Types Carried Over `%skein`

- listing gossip: `%listing`, `%catalog-request`, `%catalog`, `%listing-retracted`
- moderator gossip: `%moderator-profile`, `%moderator-retracted`
- thread messages: `%direct-message`, `%offer`, `%accept`, `%reject`, `%invoice`, `%payment-proof`, `%fulfill`, `%complete`, `%dispute`, `%verdict`, `%attest`
- escrow messages: `%escrow-propose`, `%escrow-agree`, `%escrow-funded`, `%escrow-sign-release`, `%escrow-sign-refund`, `%escrow-notify`, `%escrow-dispute`, `%escrow-assembled`
- reliability and reconciliation: `%ack`, `%sync-thread`, `%sync-thread-response`

`%counter-offer`, `%ping`, and `%pong` are typed but not yet part of the main UI/API flow.

## Live Flow Today

The implemented user flow is:

1. Add marketplace peers manually or discover them through the `%silk-market` channel on `%skein`.
2. Gossip listings, nym routes, and moderator profiles over `%skein`. Peers auto-exchange catalogs on discovery.
3. Open contact with a direct message or an offer. Each purchase creates a unique thread.
4. Accept or reject an offer. Accepting decrements the listing's inventory count.
5. Choose one of two payment paths:
   - direct settlement: seller sends an invoice and silk-core generates a fresh Zenith address for that transaction
   - escrowed settlement: buyer proposes a moderator, seller agrees, silk-core derives the 2-of-3 multisig address, and the invoice is auto-sent to that multisig address
6. Buyer either:
   - uses `pay-invoice` from a local Zenith account, which polls until the invoice address verifies and then auto-submits payment proof
   - or submits an external payment proof manually with `submit-payment`
7. For escrowed orders, payment submission moves escrow into the funded / escrowed path and queries chain account metadata for later multisig signing.
8. Seller marks fulfillment.
9. Buyer confirms completion. If escrow is active, completion auto-starts the release-signing path.
10. Buyer, seller, and moderator can collect release or refund signatures. Once 2 signatures are present locally, silk-core assembles the raw tx, stores the tx hex, broadcasts it through `%silk-zenith`, and polls until the multisig balance reflects confirmation.
11. Either party can cancel before payment. Reject / cancel on an active escrow can auto-start the refund path.
12. Either side can file a dispute. Moderators can sign release / refund, but full verdict-driven adjudication is still incomplete.
13. After completion, either side can leave feedback / attestations.

Thread state is stored newest-first with a running hash chain. If peers disagree about thread history, `sync-thread` and `sync-thread-response` let them reconcile by comparing chain hashes and message counts.

Critical messages are tracked in a pending-acks map with bounded retry and exponential backoff.

The `orders` screen in the UI is a projection derived from thread state in `%silk-core`, enriched with escrow and verification data. It is not yet a direct view of `%silk-market`.

## HTTP API

Authenticated via Eyre session cookie at `/apps/silk/api`.

### `GET` endpoints

- `/nyms`
- `/listings`
- `/threads`
- `/peers`
- `/orders`
- `/reputation`
- `/moderators`
- `/escrow/<thread-id>`
- `/my-escrows`
- `/zenith-accounts`
- `/stats`
- `/escrow-debug` (debug-only)

Notes:

- `/orders` is synthesized from `%silk-core` thread state plus escrow / verification data
- `/reputation` is synthesized in `%silk-core` from its attestation cache
- `/my-escrows` returns escrows where the local ship holds the moderator private key

### `POST` actions

```json
{"action":"create-nym","label":"anon-vendor","wallet":"zenith1..."}
{"action":"drop-nym","id":"0v..."}
{"action":"post-listing","title":"...","description":"...","price":100,"currency":"sZ","nym":"0v...","inventory":10}
{"action":"retract-listing","id":"0v..."}
{"action":"update-inventory","id":"0v...","inventory":5}
{"action":"add-peer","ship":"~sampel-palnet"}
{"action":"drop-peer","ship":"~sampel-palnet"}
{"action":"sync-catalog"}
{"action":"send-offer","listing_id":"0v...","seller":"0v...","amount":100,"currency":"sZ","nym":"0v..."}
{"action":"accept-offer","thread_id":"0v...","offer_id":"0v..."}
{"action":"reject-offer","thread_id":"0v...","offer_id":"0v...","reason":"too low"}
{"action":"cancel-thread","thread_id":"0v...","reason":"changed my mind"}
{"action":"send-invoice","thread_id":"0v..."}
{"action":"submit-payment","thread_id":"0v...","tx_hash":"0x..."}
{"action":"pay-invoice","thread_id":"0v...","account":"default"}
{"action":"mark-fulfilled","thread_id":"0v...","note":"delivered"}
{"action":"confirm-complete","thread_id":"0v..."}
{"action":"leave-feedback","thread_id":"0v...","score":80,"note":"smooth trade","nym":"0v..."}
{"action":"send-message","listing_id":"0v...","nym":"0v...","text":"hello"}
{"action":"send-reply","thread_id":"0v...","nym":"0v...","text":"reply"}
{"action":"verify-payment","thread_id":"0v..."}
{"action":"file-dispute","thread_id":"0v...","reason":"item not delivered","nym":"0v..."}
{"action":"register-moderator","nym_id":"0v...","fee_bps":200,"stake_amount":100000,"description":"fast arbiter"}
{"action":"retract-moderator","id":"0v..."}
{"action":"propose-escrow","thread_id":"0v...","moderator":"0v...","timeout":86400}
{"action":"agree-escrow","thread_id":"0v..."}
{"action":"fund-escrow","thread_id":"0v...","tx_hash":"0x..."}
{"action":"release-escrow","thread_id":"0v..."}
{"action":"refund-escrow","thread_id":"0v..."}
{"action":"sign-escrow","thread_id":"0v...","escrow_action":"release"}
{"action":"rebroadcast-escrow","thread_id":"0v..."}
```

Notes:

- `send-invoice` uses a direct invoice address only when escrow is not active
- agreeing to escrow auto-sends the invoice to the derived multisig address
- `pay-invoice` uses a local Zenith account name and then polls for payment verification
- `verify-payment` checks invoice-address balance for direct settlement, or escrow confirmation state for release / refund broadcasts
- `fund-escrow` and `rebroadcast-escrow` are mainly useful for manual recovery / testing
- `sign-escrow` is the moderator-signing endpoint

## Scries And Watches

### `%silk-core`

Scries:

- `/x/nyms`
- `/x/listings`
- `/x/threads`
- `/x/thread/<thread-id>`
- `/x/peers`
- `/x/stats`

Watch:

- `/events`

### `%silk-market`

Scries:

- `/x/orders`
- `/x/order/<thread-id>`
- `/x/stats`

Watch:

- `/market-events`

### `%silk-rep`

Scries:

- `/x/scores`
- `/x/score/<nym-id>`
- `/x/issued`
- `/x/received`
- `/x/stats`

Watch:

- `/rep-events`

### `%silk-zenith`

Scries:

- `/x/payments`
- `/x/payment/<invoice-id>`
- `/x/addresses`
- `/x/mode`
- `/x/stats`

Watch:

- `/zenith-events`

## Frontend

The UI in `ui/` is a Vite single-page app bundled with `vite-plugin-singlefile`.

Current views:

- Dashboard
- Identities
- Marketplace
- Threads
- Orders
- Reputation
- Moderators
- Network

The moderators view also contains the local `My Escrows` moderator panel.

The network view talks to the local `%skein` API so operators can:

- add or remove marketplace peers
- discover or drop relay descriptors
- raise or lower `%skein` minimum relay hops
- toggle adaptive hops
- manage seed ships and relay trust

`./sync` builds the UI, globs it, uploads the glob to R2, updates `desk/desk.docket-0`, and rsyncs the desk to the configured pier path.

## Known Gaps

The important implementation holes today are:

- `%silk-market` validates transitions but is not yet the authoritative gate; `%silk-core` still mutates thread state directly
- moderator `fee_bps` is stored and exposed, but escrow auto-invoicing currently uses a fixed `200.000` fee instead of applying the configured basis points
- `%silk-zenith` payment-record and address-pool logic is not yet the main direct-settlement path
- attestation signatures and pseudonym keys are local-only trust material; inbound attestations are imported without verification
- dispute filing exists, but there is no complete moderator verdict API / UI flow yet, and `%split` currently collapses to seller release
- moderator profile `address` is not yet populated with a derived Zenith address
- thread sync reconciliation messages are typed and handled, but not automatically initiated as a background recovery process
- counter-offers and negotiation-key material are defined but not yet exercised in the live flow
