# silk

`%silk` is a decentralized marketplace protocol built on top of `../skein`. It separates transport identity, market pseudonyms, and payment identity, and it routes all peer traffic over `%skein` rather than direct ship-to-ship pokes.

For design intent and threat-model notes, see [docs/silk-architecture.md](docs/silk-architecture.md). That document is still partly aspirational. This README is a description of the code as it exists now.

## Current Status

Implemented today:

- pseudonyms with labels, ed25519 keypairs, and wallet strings
- listing publication, retraction, and per-listing inventory tracking (auto-decrement on accept, restore on cancel)
- marketplace peer management and catalog sync over `%skein`
- automatic peer discovery via the `%silk-market` channel on `%skein`
- direct messages, offers, accepts, rejects, invoices, payment proofs, fulfillment messages, completion, disputes, verdicts, cancel, and feedback messages
- per-thread hash chains plus `sync-thread` / `sync-thread-response` reconciliation messages
- unique per-transaction thread ids (each purchase is a separate thread, even with the same counterparty and listing)
- per-transaction payment addresses generated via `%zenith` (fresh keypair per invoice, bech32 address derived through the local zenith agent)
- `%khan`-based balance verification against the per-transaction payment address
- `%silk-market` as a wired-in order state machine (silk-core sends advance cards on each transition; market validates and rejects illegal transitions)
- `%silk-zenith` address pool and payment record tracking
- ack-driven resend with bounded retry and exponential backoff for critical messages
- HTTP JSON API for the frontend
- a complete browser UI for identities, listings, threads, orders, reputation, and network management
- local reputation storage and simple aggregate scoring via `%silk-rep`

Not yet implemented:

- `%silk-market` is wired in but not yet the authoritative source of truth; `%silk-core` still drives most thread state directly
- pseudonym and attestation crypto fields exist, but signatures are placeholders and are not verified on import
- escrow hold and release is scaffolded but not connected to a real on-chain escrow flow
- dispute adjudication and verdict-driven resolution have message types but no complete workflow

## System Split

Silk is intentionally split across two desks:

- `../skein`: content-agnostic transport, routing, relay discovery, and delivery
- `%silk`: marketplace semantics, pseudonyms, listings, negotiation, payment coordination, and reputation

Silk also separates three identities:

- `ship`: the Urbit transport identity used by `%skein`
- `pseudonym`: the market-facing `nym-id` with its own keypair
- `wallet` / payment address: per-transaction bech32 addresses derived through `%zenith`, decoupled from both ship and pseudonym

## Agents

### `%silk-core`

`desk/app/silk-core.hoon` (state-6) is the live hub.

It owns:

- pseudonyms and their ed25519 keypairs
- listings and per-listing inventory counts
- peer ships (auto-discovered via `%skein` channels and manually managed)
- route mappings from `nym-id` to `%skein` endpoints
- thread state and message logs
- local attestation cache
- Zenith verification snapshots
- pending message acks and resend state
- the JSON API at `/apps/silk/api`
- the `/events` fact stream used by the UI

On invoice creation, silk-core generates a fresh private key, pokes `%zenith %add-account` to register it, then scries the derived bech32 address back and includes it in the invoice sent to the buyer. On payment verification, it fires a `%khan` balance check against that per-transaction address.

silk-core notifies `%silk-market` of order state transitions via advance cards. Market validates the transition and rejects illegal ones; silk-core logs invalid-transition events from market.

### `%silk-market`

`desk/app/silk-market.hoon` (state-0) implements the order state machine:

- `offered -> accepted -> invoiced -> paid -> escrowed -> fulfilled -> completed`
- explicit invalid-transition reporting and same-state no-ops
- escrow records
- completion-triggered attestation issuance into `%silk-rep`

It is wired into the live flow as a sidecar: silk-core sends advance cards on each state change, and market validates legality. It is not yet the authoritative gate for mutations — silk-core can still update thread state independently.

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
- address pools per seller nym
- payment records per invoice
- invoice creation, payment recording, confirmation, and failure events

silk-core uses `%zenith` directly for per-transaction address generation (poke `%add-account`, scry address). silk-zenith maintains its own payment records and can advance `%silk-market` to escrowed on payment confirmation.

## Protocol Surface

Core types live in `desk/sur/silk.hoon`.

### Identity And Reputation Types

- `pseudonym`: id, label, pubkey, wallet, created-at
- `nym-keypair`: pub + sec signing keys
- `attestation`: signed claim with kind, score, note
- `nym-route`: maps a nym-id to a skein endpoint

### Marketplace And Thread Types

- `listing`: id, seller, title, description, price, currency, created-at, optional expiry
- `offer`: thread-id, listing-id, buyer, seller, amount, currency, note
- `accept` / `reject`
- `invoice`: id, thread-id, offer-id, seller, amount, currency, pay-address, expires-at
- `payment-proof`: thread-id, invoice-id, tx-hash, paid-at
- `fulfillment`: thread-id, offer-id, note, opaque payload
- `dispute` / `verdict`
- `silk-thread`: id, listing-id, buyer, seller, status, messages, chain hash, timestamps

### Message Types Carried Over `%skein`

- listing gossip: `%listing`, `%catalog-request`, `%catalog`, `%listing-retracted`
- thread messages: `%direct-message`, `%offer`, `%accept`, `%reject`, `%invoice`, `%payment-proof`, `%fulfill`, `%complete`, `%dispute`, `%verdict`, `%attest`
- reliability and reconciliation: `%ack`, `%sync-thread`, `%sync-thread-response`

`%counter-offer`, `%ping`, and `%pong` are typed but not yet part of the main UI/API flow.

## Live Flow Today

The implemented user flow is:

1. Add marketplace peers manually or discover them through the `%silk-market` channel on `%skein`.
2. Gossip listings and nym routes over `%skein`. Peers auto-exchange catalogs on discovery.
3. Open contact with a direct message or an offer (each purchase creates a unique thread).
4. Accept or reject an offer. Accepting decrements the listing's inventory count.
5. Send an invoice — silk-core generates a fresh keypair, registers it with `%zenith`, scries the bech32 address, and sends the invoice to the buyer with that per-transaction address.
6. Submit a payment proof with the transaction hash.
7. Verify payment — fires a `%khan` balance check against the per-transaction payment address.
8. Mark fulfillment.
9. Confirm completion.
10. Exchange feedback / attestations.

Either party can cancel a thread before payment. The buyer can cancel at any point before paying. The seller can cancel before payment is submitted. Canceling an accepted offer restores the inventory count.

Thread state is stored newest-first with a running hash chain. If peers disagree about thread history, `sync-thread` and `sync-thread-response` let them reconcile by comparing chain hashes and message counts.

Critical messages (payment proofs, fulfillment, etc.) are tracked in a pending-acks map with bounded retry and exponential backoff.

The `orders` screen in the UI is a projection derived from thread state in `%silk-core`, enriched with verification data. It is not yet a direct view of `%silk-market`.

## HTTP API

Authenticated via Eyre session cookie at `/apps/silk/api`.

### `GET` endpoints

- `/nyms`
- `/listings`
- `/threads`
- `/peers`
- `/orders`
- `/reputation`
- `/stats`

Notes:

- `/orders` is synthesized from `%silk-core` thread data plus cached verification data
- `/reputation` is synthesized in `%silk-core` from its attestation cache

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
{"action":"mark-fulfilled","thread_id":"0v...","note":"delivered"}
{"action":"confirm-complete","thread_id":"0v..."}
{"action":"leave-feedback","thread_id":"0v...","score":80,"note":"smooth trade","nym":"0v..."}
{"action":"send-message","listing_id":"0v...","nym":"0v...","text":"hello"}
{"action":"send-reply","thread_id":"0v...","nym":"0v...","text":"reply"}
{"action":"verify-payment","thread_id":"0v..."}
```

`send-invoice` generates a per-transaction Zenith address and includes it in the invoice. `verify-payment` fires a `%khan` balance check against that address and stores a local verification snapshot.

`post-listing` accepts an `inventory` field (0 = unlimited). `update-inventory` lets the seller adjust it after posting.

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
- Network

The network view also talks to the local `%skein` API so operators can:

- add or remove marketplace peers
- discover or drop relay descriptors
- raise or lower `%skein` minimum relay hops
- toggle adaptive hops
- manage seed ships and relay trust

`./sync` builds the UI, globs it, uploads the glob to R2, updates `desk/desk.docket-0`, and rsyncs the desk to the configured pier path.

## Known Gaps

The important implementation holes today are:

- `%silk-market` validates transitions but is not yet the authoritative gate; `%silk-core` can still mutate thread state independently
- escrow hold and release is scaffolded in market and zenith but not connected to real on-chain escrow
- attestation signatures and pseudonym keys are placeholders; inbound attestations are imported without verification
- counter-offers and negotiation-key material are defined but not yet exercised in the live flow
- dispute filing and verdict messages exist, but there is no complete adjudication or escrow-release workflow
- thread sync reconciliation messages are typed but not automatically triggered
