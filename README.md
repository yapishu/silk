# silk

`%silk` is a decentralized marketplace protocol built on top of `../skein`. It separates transport identity, market pseudonyms, and payment identity, and it routes all peer traffic over `%skein` rather than direct ship-to-ship pokes.

For design intent and threat-model notes, see [docs/silk-architecture.md](docs/silk-architecture.md). That document is still partly aspirational. This README is a description of the code as it exists now.

## Current Status

Implemented today:

- pseudonyms with labels, stored pubkey fields, and wallet strings
- listing publication and listing retraction
- marketplace peer management and catalog sync over `%skein`
- direct messages, offers, accepts, rejects, invoices, payment proofs, fulfillment messages, completion, disputes, verdicts, and feedback messages
- per-thread hash chains plus `sync-thread` / `sync-thread-response` reconciliation messages
- HTTP JSON API for the frontend
- a complete browser UI for identities, listings, threads, orders, reputation, and network management
- local reputation storage and simple aggregate scoring
- Zenith balance checks through `%khan`

Partially implemented but not yet authoritative in the live flow:

- `%silk-market` has an order state machine, but `%silk-core` does not currently drive commerce through it
- `%silk-zenith` has address-pool and payment-record scaffolding, but the main invoice flow still derives the pay address directly from the seller nym wallet
- pseudonym and attestation crypto fields exist, but signatures are placeholders and are not verified

The practical result is that `%silk-core` currently carries most of the live application flow, while `%silk-market` and `%silk-zenith` are real sidecars that still need to be wired in as authoritative components.

## System Split

Silk is intentionally split across two desks:

- `../skein`: content-agnostic transport, routing, relay discovery, and delivery
- `%silk`: marketplace semantics, pseudonyms, listings, negotiation, payment coordination, and reputation

Silk also separates three identities:

- `ship`: the Urbit transport identity used by `%skein`
- `pseudonym`: the market-facing `nym-id`
- `wallet` / payment address: the settlement-side identifier currently stored on the nym and echoed into invoices

## Agents

### `%silk-core`

`desk/app/silk-core.hoon` is the live hub today.

It owns:

- pseudonyms
- listings
- peer ships
- route mappings from `nym-id` to `%skein` endpoints
- thread state and message logs
- local attestation cache
- Zenith verification snapshots
- the JSON API at `/apps/silk/api`
- the `/events` fact stream used by the UI

This is the agent that currently drives the end-to-end user flow.

### `%silk-market`

`desk/app/silk-market.hoon` implements a separate order state machine with:

- `offered -> accepted -> invoiced -> paid -> escrowed -> fulfilled -> completed`
- explicit invalid-transition reporting
- escrow records
- completion-triggered attestation issuance into `%silk-rep`

It has its own scries and event stream, but it is not yet wired into `%silk-core` as the source of truth for the live order flow.

### `%silk-rep`

`desk/app/silk-rep.hoon` stores issued and imported attestations and computes a simple average score per subject nym.

This agent is partially live today:

- `%silk-core` imports inbound attestations into `%silk-rep`
- locally authored feedback is also issued into `%silk-rep`

The API-facing reputation view is still assembled in `%silk-core`.

### `%silk-zenith`

`desk/app/silk-zenith.hoon` tracks:

- wallet mode (`%local` or `%external`)
- address pools per seller nym
- payment records per invoice
- invoice creation, payment recording, confirmation, and failure events

The scaffolding exists, but `%silk-core` is not yet using it as the authoritative payment path.

### `%silk`

`desk/app/silk.hoon` is still a template stub and is not part of the marketplace protocol.

## Protocol Surface

Core types live in `desk/sur/silk.hoon`.

### Identity And Reputation Types

- `pseudonym`
- `attestation`
- `nym-route`

### Marketplace And Thread Types

- `listing`
- `offer`
- `accept`
- `reject`
- `invoice`
- `payment-proof`
- `fulfillment`
- `dispute`
- `verdict`
- `silk-thread`

### Message Types Carried Over `%skein`

- listing gossip: `%listing`, `%catalog-request`, `%catalog`, `%listing-retracted`
- thread messages: `%direct-message`, `%offer`, `%counter-offer`, `%accept`, `%reject`, `%invoice`, `%payment-proof`, `%fulfill`, `%complete`, `%dispute`, `%verdict`, `%attest`
- reliability and reconciliation: `%ack`, `%sync-thread`, `%sync-thread-response`, `%ping`, `%pong`

Some of these are defined earlier than they are used. In particular, `%counter-offer`, `%ping`, and `%pong` are typed but not yet part of the main UI/API flow.

## Live Flow Today

The implemented user flow is:

1. Add marketplace peers or discover them through the `%skein` channel network.
2. Gossip listings and nym routes over `%skein`.
3. Open contact with a direct message or an offer.
4. Accept or reject an offer.
5. Create an invoice from the seller nym's wallet string.
6. Submit a payment proof.
7. Mark fulfillment.
8. Confirm completion.
9. Exchange feedback / attestations.

Thread state is stored newest-first with a running hash chain. If peers disagree about thread history, `sync-thread` and `sync-thread-response` let them reconcile by comparing chain hashes and message counts.

The `orders` screen in the UI is currently a projection derived from thread state in `%silk-core`. It is not yet a direct view of `%silk-market`.

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
- `/reputation` is also synthesized in `%silk-core` from its attestation cache

### `POST` actions

```json
{"action":"create-nym","label":"anon-vendor","wallet":"zenith1..."}
{"action":"drop-nym","id":"0v..."}
{"action":"post-listing","title":"...","description":"...","price":100,"currency":"sZ","nym":"0v..."}
{"action":"retract-listing","id":"0v..."}
{"action":"add-peer","ship":"~sampel-palnet"}
{"action":"drop-peer","ship":"~sampel-palnet"}
{"action":"sync-catalog"}
{"action":"send-offer","listing_id":"0v...","seller":"0v...","amount":100,"currency":"sZ","nym":"0v..."}
{"action":"accept-offer","thread_id":"0v...","offer_id":"0v..."}
{"action":"reject-offer","thread_id":"0v...","offer_id":"0v...","reason":"too low"}
{"action":"send-invoice","thread_id":"0v..."}
{"action":"submit-payment","thread_id":"0v...","tx_hash":"0x..."}
{"action":"mark-fulfilled","thread_id":"0v...","note":"delivered"}
{"action":"confirm-complete","thread_id":"0v..."}
{"action":"leave-feedback","thread_id":"0v...","score":80,"note":"smooth trade","nym":"0v..."}
{"action":"send-message","listing_id":"0v...","nym":"0v...","text":"hello"}
{"action":"send-reply","thread_id":"0v...","nym":"0v...","text":"reply"}
{"action":"verify-payment","thread_id":"0v..."}
```

`verify-payment` currently fires a `%khan` balance query against the seller wallet and stores a local verification snapshot. It is not yet a transaction-proof or escrow verifier.

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

`./sync` builds the UI, globs it, updates `desk/desk.docket-0`, and rsyncs the desk to the configured pier path.

## Known Gaps

The important implementation holes today are:

- `%silk-core` accepts most thread mutations directly and does not yet use `%silk-market` as the authoritative legality check
- invoice generation is still tied directly to the seller nym wallet string; `%silk-zenith` address rotation is not in the live path
- `verify-payment` checks wallet balance, not proof of payment to a specific invoice address or escrow contract
- attestation signatures and pseudonym keys are placeholders; inbound attestations are imported without verification
- counter-offers, keepalives, and negotiation-key material are defined but not yet exercised in the live flow
- dispute filing and verdict messages exist, but there is no complete adjudication or escrow-release workflow
- availability is still mostly best-effort; there are no retries, escrow watchers, or authoritative settlement confirmations yet

So the repo already demonstrates the transport split, catalog sync, anonymous negotiation threads, and a usable browser UX, but the trust-minimized exchange story still needs the `market` and `zenith` agents to become the real backbone rather than sidecars.
