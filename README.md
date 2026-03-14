# %silk

`%silk` is a marketplace protocol and app suite for Urbit built on top of `%skein`. It is trying to give you an OpenBazaar-like flow on Urbit: pseudonymous identities, listings, negotiation threads, optional moderator escrow, and routed messaging that does not depend on direct ship-to-ship application pokes.

The project is split cleanly in principle:

- `%skein` is the transport layer
- `%silk` is the marketplace layer
- Zenith is the settlement rail

## What `%silk` does today

- Creates local market pseudonyms with Ed25519 signing keys
- Publishes and retracts listings
- Syncs catalogs with marketplace peers
- Opens direct message and offer threads over `%skein`
- Supports offer, accept, reject, invoice, payment-proof, fulfillment, completion, dispute, and verdict messages
- Tracks per-thread hash chains and supports `sync-thread` reconciliation
- Retries important messages with bounded ack-driven resend
- Supports direct settlement invoices and local `pay-invoice`
- Supports optional 2-of-3 escrow with a moderator, multisig address derivation, signature exchange, raw transaction assembly, rebroadcast, and confirmation polling
- Stores feedback and basic reputation data
- Exposes a browser UI for identities, listings, threads, orders, moderators, and escrow state

## Desk layout

`%silk` currently ships as four Gall agents:

- `%silk-core`: identities, listings, threads, contacts, messaging, escrow orchestration, HTTP API
- `%silk-market`: order state machine
- `%silk-rep`: feedback and reputation storage
- `%silk-zenith`: payment and escrow helper for Zenith integration

## Identity model

Silk is trying to keep three identities separate:

- `ship`: the Urbit transport identity
- `nym`: the market-facing pseudonym
- `wallet`: the payment identity used on Zenith

For direct marketplace messaging, `%silk` stores opaque `%skein` contact bundles rather than raw `nym -> ship` routes. That is the right direction for the privacy boundary.

## What the user flow looks like

1. Create one or more nyms.
2. Add marketplace peers, or let Silk probe known Skein relays for other Silk peers.
3. Sync catalogs and discover listings.
4. Open a thread with a direct message or an offer.
5. Negotiate, accept or reject, and move to invoice.
6. Either pay directly or use moderator escrow.
7. Fulfill, complete, dispute, or resolve.
8. Leave feedback.

Every order lives inside a thread. Threads are the durable message log and the UI's main source of user-visible state.

## Current privacy boundary

What Silk is already doing:

- all peer traffic goes through `%skein`
- listings and threads use opaque contact bundles instead of direct route records
- local nyms get their own Skein contact bundles, and those bundles are rotated
- transport identity, market nym, and payment address are separate types in the protocol

What Silk does not yet guarantee:

- that a counterparty can never infer your Urbit ship
- that marketplace discovery is fully anonymous
- that moderator and dispute traffic never falls back to ship-level peer gossip
- that Zenith payments are private

In other words: Silk is already better than a direct ship-to-ship marketplace app, but the anonymity boundary is not complete yet.

## Important current limitations

- `%silk-market` is not yet the sole authority for order legality; `%silk-core` still mutates thread state directly
- many outbound packet signatures and reply bundles still use the default local nym rather than the exact acting nym for that action
- peer discovery and catalog sync are still ship-addressed
- `%split` verdicts do not yet produce a real split payout path
- dispute handling is present, but not yet a complete evidence-driven adjudication workflow

## API and UI surface

The UI lives in [`ui/`](ui/) and talks to the HTTP API served by `%silk-core` at `/apps/silk/api`.

Current API-backed views include:

- nyms
- listings
- threads
- orders
- reputation
- moderators
- escrow detail
- marketplace peers
- stats

## Relationship to `%skein`

Silk should be read as an application protocol over Skein, not as a transport layer itself.

- `%skein` decides how packets move
- `%silk` decides what those packets mean

That split matters because the main long-term goal is simple: you should be able to participate in the market as a pseudonym without handing counterparties your Urbit identity just to buy or sell something.
