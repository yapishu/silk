# silk

`%silk` is a decentralized marketplace protocol built on top of the [skein](https://github.com/yapishu/skein) mixnet. It models transport identity, market pseudonyms, and payment identity as separate concerns, and it routes all peer traffic over `%skein` rather than direct ship-to-ship pokes.

## Current status

Implemented today:

- pseudonyms with labels, local ed25519 keypairs, and wallet strings
- listing publication, retraction, and per-listing inventory tracking
- marketplace peer management and catalog sync over `%skein`
- automatic peer discovery via the `%silk-market` channel on `%skein`
- `%skein` contact bundles carried as `nym-contact`s in `%catalog`
- signed `silk-packet`s with reply bundles for ongoing direct messaging
- direct messages, offers, accepts, rejects, invoices, payment proofs, fulfillment messages, completion, disputes, verdict messages, cancel, and feedback messages
- per-thread hash chains plus `sync-thread` / `sync-thread-response` reconciliation messages
- unique per-transaction thread ids
- direct-settlement invoices with per-transaction Zenith addresses generated through the local `%zenith` agent
- `pay-invoice` via a local Zenith account, with polling that auto-submits payment proof once the invoice address verifies
- `%khan`-based balance verification against invoice addresses
- optional 2-of-3 escrow multisigs with moderator selection, per-thread secp256k1 keys, multisig address derivation, signature collection, raw tx assembly, rebroadcast, broadcast via `%silk-zenith`, post-broadcast confirmation polling, and moderator `fee_bps` deduction from release payouts
- moderator registration, gossip, local moderator key storage, `/my-escrows` moderator view, and verdict-triggered escrow auto-resolution
- Ed25519 attestation signature verification on inbound attestations for known local issuers
- `%silk-market` as a wired-in order state machine sidecar
- `%silk-zenith` escrow account-number / sequence lookup and raw escrow tx broadcast bridge
- ack-driven resend with bounded retry and exponential backoff for critical messages
- a browser UI for identities, listings, threads, orders, reputation, moderators, and network management
- local reputation storage and simple aggregate scoring via `%silk-rep`
- `tools/verify-multisig/` to cross-check multisig address derivation against the Cosmos SDK

Current limitations:

- `%skein` contact bundles are plain jammed `[%contact-v1 endpoint reply-block]` values rather than sealed capability objects
- all local nyms reuse the same locally minted contact bundle and share one rotation timer
- `%silk-market` validates transitions but is not yet the authoritative gate for mutations
- `%silk-zenith` contains address-pool and payment-record machinery, while the main invoice and wallet-send path runs through `%silk-core` talking directly to `%zenith`
- inbound attestations from unknown issuers are accepted without signature verification
- moderator and dispute flows use peer gossip when no direct moderator contact is known
- moderator verdict auto-triggers escrow release/refund, but `%split` collapses to seller release and moderator fee remainder is not yet paid out
- counter-offers, `%ping`, `%pong`, and negotiation-key material are typed but not part of the main UI/API flow

## System split

Silk is intentionally split across two desks:

- [`%skein`](https://github.com/yapishu/skein): content-agnostic transport, routing, relay discovery, and delivery
- `%silk`: marketplace semantics, pseudonyms, listings, negotiation, payment coordination, moderators, escrow, and reputation

Silk also separates three identities:

- `ship`: the Urbit transport identity used by `%skein`
- `pseudonym`: the market-facing `nym-id` with its own keypair
- `wallet` / payment address: direct invoice addresses or escrow multisig addresses on Zenith, decoupled from both ship and pseudonym

## Deanonymization limits

Current deanonymization limits that do not require endpoint compromise or full-network visibility:

- `%catalog` gossip distributes `nym-contact`s to peers, but the current `%skein` contact-bundle format is just jammed `[%contact-v1 endpoint reply-block]`, so a peer that knows the type can recover the destination ship and app
- `%silk-core` copies the same locally minted contact bundle to every local nym and rotates it on a shared 12-hour timer, so multiple nyms on one ship are trivially linkable
- direct-message, offer, and accept flows rely on those catalog contacts and per-message reply bundles, so counterparties can cache and compare the same underlying bundle material over time
- `%silk-market` channel discovery exposes participating ships to channel subscribers and relay hosts
- relay discovery depends on unsigned `/relay/pool` gossip from a small seed set, so malicious seeds or Sybil relays can bias path selection without owning the whole network
- moderator and dispute flows can fall back to peer gossip, which reveals relationships to the peer set
- payment flows are chain-visible; direct invoice addresses are per-transaction, but escrow exposes a shared multisig plus release and refund wallet destinations

## Agents

### `%silk-core`

`desk/app/silk-core.hoon` is the live hub.

It owns:

- pseudonyms and their local ed25519 keypairs
- listings and per-listing inventory counts
- contact bundles learned for remote nyms
- peer ships
- locally minted contact bundles reused across our current nyms
- thread state and message logs
- local attestation cache
- payment verification snapshots
- moderator directory and local moderator private keys
- per-thread escrow configs, signer keys, collected signatures, and assembled tx hex
- pending message acks and resend state
- the `/events` fact stream used by the UI

For peer traffic, silk-core signs each outbound `silk-message`, wraps it in `silk-packet`, attaches reply material when it has a current bundle, and hands the jammed packet to `%skein`. On inbound packets it verifies signatures when it has the sender key, and it updates its `contacts` cache from the attached reply bundle.

For direct invoices, silk-core generates a fresh private key, pokes `%zenith %add-account`, scries the derived bech32 address back, and includes that address in the invoice sent to the buyer. `pay-invoice` sends through the local `%zenith` agent and then polls the invoice address until the balance verifies.

For escrowed orders, silk-core derives the 2-of-3 multisig address, auto-invoices the buyer to that address, collects release / refund signatures, assembles the raw transaction once 2 signatures are present locally, and asks `%silk-zenith` to broadcast it and query account metadata needed for signing.

silk-core also notifies `%silk-market` of order-state transitions via advance cards. Market validates the transition and emits invalid-transition events, while silk-core mutates its own thread state first.

### `%silk-market`

`desk/app/silk-market.hoon` implements the order state machine:

- `offered -> accepted -> escrow-proposed -> escrow-agreed -> invoiced -> paid -> escrowed -> fulfilled -> completed`
- dispute branches to `disputed -> resolved`, plus cancellation
- explicit invalid-transition reporting and same-state no-ops
- escrow records on `%set-escrow`
- completion-triggered attestation issuance into `%silk-rep`

It is wired into the live flow as a sidecar. silk-core creates and advances orders there, but market is not yet the authoritative source of truth.

### `%silk-rep`

`desk/app/silk-rep.hoon` stores issued and imported attestations and computes a simple average score per subject nym.

This agent is live:

- `%silk-core` imports inbound attestations into `%silk-rep`
- locally authored feedback is issued into `%silk-rep`
- completion of an order in `%silk-market` triggers attestation issuance

The API-facing reputation view is assembled in `%silk-core`.

### `%silk-zenith`

`desk/app/silk-zenith.hoon` tracks:

- wallet mode (`%local` or `%external`)
- optional address pools per seller nym
- payment records per invoice
- escrow tx broadcast requests
- escrow account-number / sequence lookups

`%silk-zenith` is used mainly in the escrow path and as an auxiliary wallet/data bridge. The main direct invoice-address generation and wallet-send flow lives in `%silk-core` talking to `%zenith` directly.

## Protocol surface

Core types live in `desk/sur/silk.hoon`.

### Identity, reputation, and moderator types

- `pseudonym`: id, label, pubkey, wallet, created-at
- `nym-keypair`: local pub + sec signing keys
- `attestation`: signed claim with kind, score, note
- `nym-contact`: maps a nym-id to an opaque `%skein` contact-bundle
- `silk-packet`: sender nym, signature, optional reply bundle, and the wrapped `silk-message`
- `moderator-profile`: moderator nym, secp256k1 pubkey, fee metadata, claimed stake metadata, description

### Marketplace, thread, and escrow types

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

### Message types carried over `%skein`

These are carried inside `silk-packet`, which adds sender, signature, and reply material around the raw `silk-message`.

- listing gossip: `%listing`, `%catalog-request`, `%catalog`, `%listing-retracted`
- moderator gossip: `%moderator-profile`, `%moderator-retracted`
- thread messages: `%direct-message`, `%offer`, `%accept`, `%reject`, `%invoice`, `%payment-proof`, `%fulfill`, `%complete`, `%dispute`, `%verdict`, `%attest`
- escrow messages: `%escrow-propose`, `%escrow-agree`, `%escrow-funded`, `%escrow-sign-release`, `%escrow-sign-refund`, `%escrow-notify`, `%escrow-dispute`, `%escrow-assembled`
- reliability and reconciliation: `%ack`, `%sync-thread`, `%sync-thread-response`

`%counter-offer`, `%ping`, and `%pong` are typed but not yet part of the main UI/API flow.

## Live flow today

The implemented user flow is:

1. Add marketplace peers manually or discover them through the `%silk-market` channel on `%skein`.
2. Gossip listings, nym contacts, and moderator profiles over `%skein`. Peers auto-exchange catalogs on discovery.
3. Open contact with a direct message or an offer. The first message usually comes from a catalog contact, and later replies use the reply bundle attached to the last message. Each purchase creates a unique thread.
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
12. Either side can file a dispute. Moderators can sign release / refund, direct moderator contact uses peer gossip when no direct moderator contact is known, and full verdict-driven adjudication is still incomplete.
13. After completion, either side can leave feedback / attestations.

Thread state is stored newest-first with a running hash chain. If peers disagree about thread history, `sync-thread` and `sync-thread-response` let them reconcile by comparing chain hashes and message counts.

Critical messages are tracked in a pending-acks map with bounded retry and exponential backoff.

The `orders` screen in the UI is a projection derived from thread state in `%silk-core`, enriched with escrow and verification data. It is not yet a direct view of `%silk-market`.

## Scries and watches

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

The network view talks to the local `%skein` agent so operators can:

- add or remove marketplace peers
- discover or drop relay descriptors
- raise or lower `%skein` minimum relay hops
- toggle adaptive hops
- manage seed ships and relay trust

`./sync` builds the UI, globs it, uploads the glob to R2, updates `desk/desk.docket-0`, and rsyncs the desk to the configured pier path.

## Known gaps

The important implementation holes today are:

- `%silk-market` validates transitions but is not yet the authoritative gate; `%silk-core` mutates thread state directly
- `%silk-zenith` payment-record and address-pool logic is not yet the main direct-settlement path
- `%skein` contact bundles are not opaque capability objects, and `%silk` reuses one bundle across local nyms
- `%silk-market` discovery and moderator gossip expose ship-level relationship data
- dispute filing and moderator verdict auto-trigger escrow release/refund based on ruling, but `%split` currently collapses to seller release
- moderator fee remainder stays in the multisig after release; a separate moderator-payout tx is not yet implemented
- inbound attestations from unknown issuers are accepted without signature verification
- moderator profile `address` is not yet populated with a derived Zenith address
- thread sync reconciliation messages are typed and handled, but not automatically initiated as a background recovery process
- counter-offers and negotiation-key material are defined but not yet exercised in the live flow
