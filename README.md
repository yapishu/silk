# silk

Private commerce on Urbit. Buyers and sellers trade under pseudonyms, negotiate through encrypted message threads relayed via a mixnet, and settle payments through rotating addresses. No direct ship-to-ship communication -- all inter-ship messaging flows through `%skein` as opaque jammed payloads.

For detailed design rationale, see [docs/silk-architecture.md](docs/silk-architecture.md).

## Overview

Silk separates three layers of identity:

- **Ship** (transport) -- your Urbit identity, used only by `%skein` for relay routing. Never exposed to counterparties.
- **Pseudonym** (market) -- a `@uv` + label persona used for listings, offers, and reputation. Decoupled from ship identity.
- **Payment address** (settlement) -- rotated per-invoice so transactions can't be linked across trades.

The system spans two Urbit desks:

- **`%skein`** -- content-agnostic mixnet transport (separate repo at `../skein/`)
- **`%silk`** -- private commerce protocol built on top of `%skein`

## %skein -- Mixnet Transport

Generalized multi-hop relay network. Silk uses it as an opaque transport layer, but any application can bind to it.

**Agent:** `skein.hoon` (~998 lines)
**Types:** `sur/skein.hoon`, `sur/skein-crypto.hoon`
**Marks:** `skein-send`, `skein-event`, `skein-admin`, `skein-cell`

### Concepts

- **Endpoint** -- a `(ship, app-id)` pair. Apps bind to skein to send/receive.
- **Relay descriptor** -- a node in the relay network, identified by `relay-id`, carrying a ship, optional encryption key, weight, delay, and expiry.
- **Route** -- an ordered list of relay hops with per-hop encryption keys and optional delays.
- **Cell** -- an in-flight message with layered encrypted headers, routed hop-by-hop through the network.
- **Reply block** -- a pre-built return path (token + encrypted header + body) for anonymous replies.

### Features

- App bind/unbind via admin pokes
- Multi-hop routing with layered encrypted headers (onion-style)
- Replay detection with time-based pruning (~h1 TTL)
- Epoch batching (~s30 timer) to prevent timing correlation
- Relay descriptor management (add, remove, weight-based selection)
- Route diversity policy (min 2 hops, avoids reusing recent relay sets)
- Route logging capped at 100 entries
- Cover traffic generation
- Loopback delivery for same-ship messages

### Admin Actions

| Action | Description |
|--------|-------------|
| `%bind` | Register an app to send/receive through skein |
| `%unbind` | Deregister an app |
| `%clear` | Flush queued messages for an app |
| `%put-relay` | Add or update a relay descriptor |
| `%drop-relay` | Remove a relay |
| `%clear-seen` | Purge the replay detection cache |

### State (state-3)

- `apps` -- bound application registrations and queues
- `relays` -- known relay descriptors
- `seen` -- `(map relay-step @da)` for replay detection
- `recent-routes` -- last 100 route selections
- `mix` -- epoch batching state (timer, pending cells)

## %silk -- Private Commerce

Four agents handle the commerce protocol. All inter-ship communication is routed through `%skein` -- agents never poke remote ships directly.

### Agents

**`silk-core.hoon`** (517 lines) -- Protocol hub. Manages pseudonyms, listings, negotiation threads, and route mappings. Serves the HTTP JSON API at `/apps/silk/api/`. Dispatches protocol messages to/from `%skein`. Publishes `%silk-event` facts on `/events` for UI subscriptions.

**`silk-market.hoon`** (263 lines) -- Order state machine. Enforces the order lifecycle with strict transition validation. Manages escrow records. Triggers reputation attestations on completion by poking `%silk-rep`.

**`silk-rep.hoon`** (129 lines) -- Reputation tracker. Stores issued and received attestations per pseudonym. Computes aggregate scores as simple averages. Attestation kinds: `%completion`, `%fulfillment`, `%payment`, `%dispute-fair`, `%general`.

**`silk-zenith.hoon`** (242 lines) -- Payment adapter. Maintains per-pseudonym address pools with use-once rotation. Creates invoices with fresh addresses. Tracks payment lifecycle (pending -> submitted -> confirmed). On confirmation, pokes `%silk-market` to set escrow. Supports local (`%zenith` agent) and external wallet modes.

There is also a placeholder `silk.hoon` (94 lines) -- a stub app from the desk template, not part of the protocol.

### Types (`sur/silk.hoon`, 255 lines)

Core protocol types:

- `pseudonym` -- market identity (`nym-id`, label, pubkey, timestamp)
- `listing` -- seller advertisement (title, description, price, currency, expiry)
- `offer` / `accept` / `reject` -- negotiation messages
- `invoice` -- payment request with fresh address
- `payment-proof` -- tx hash submission
- `fulfillment` -- delivery confirmation
- `dispute` / `verdict` -- dispute resolution (rulings: buyer-wins, seller-wins, split, dismissed)
- `silk-thread` -- conversation state tracking a negotiation from open through completion
- `attestation` -- signed reputation claim (subject, issuer, kind, score, note)
- `silk-command` / `silk-event` -- command and event envelopes
- `nym-route` -- mapping from pseudonym to skein endpoint

### Order Lifecycle

```
offered -> accepted -> invoiced -> paid -> escrowed -> fulfilled -> completed
```

Any state can transition to `cancelled` or `disputed`. Disputes resolve to `resolved` via verdict. On completion, `%silk-market` automatically issues reputation attestations to both buyer (for payment) and seller (for fulfillment).

### Thread Status

```
open -> accepted -> paid -> fulfilled -> completed
                                      -> disputed -> resolved
       -> cancelled
```

### HTTP API

All endpoints at `/apps/silk/api/`. Authenticated via Eyre session cookie.

**GET endpoints:**

| Path | Returns |
|------|---------|
| `/nyms` | List of pseudonyms |
| `/listings` | Marketplace listings |
| `/threads` | Negotiation threads with message counts |
| `/orders` | Order records (stub -- pending silk-market scry integration) |
| `/reputation` | Scores, issued/received attestations (stub -- pending silk-rep scry integration) |
| `/stats` | Counts of nyms, listings, threads, routes, plus ship ID |

**POST actions** (all to `/apps/silk/api/`, JSON body with `action` field):

```json
{"action": "create-nym", "label": "anon-seller"}
{"action": "drop-nym", "id": "0v..."}
{"action": "post-listing", "nym": "0v...", "title": "...", "description": "...", "price": 100, "currency": "usd"}
{"action": "retract-listing", "id": "0v..."}
{"action": "send-offer", "listing_id": "0v...", "seller": "0v...", "amount": 100, "currency": "usd", "nym": "0v..."}
{"action": "accept-offer", "thread_id": "0v...", "offer_id": "0v..."}
{"action": "reject-offer", "thread_id": "0v...", "offer_id": "0v...", "reason": "too low"}
```

### Scry Endpoints

**silk-core:**
- `/x/nyms` -- all pseudonyms
- `/x/listings` -- all listings
- `/x/threads` -- all threads
- `/x/thread/<@uv>` -- single thread
- `/x/stats` -- counts

**silk-market:**
- `/x/orders` -- all orders
- `/x/order/<@uv>` -- single order
- `/x/stats` -- counts

**silk-rep:**
- `/x/scores` -- all reputation scores
- `/x/score/<@uv>` -- single nym score
- `/x/issued` -- attestations this ship issued
- `/x/received` -- attestations received
- `/x/stats` -- counts

**silk-zenith:**
- `/x/payments` -- all payment records
- `/x/payment/<@uv>` -- single payment
- `/x/addresses` -- all addresses
- `/x/mode` -- current wallet mode
- `/x/stats` -- counts

## Frontend

Vanilla JS single-page application. No framework. Dark theme. Hash-based routing.

**Views:** Dashboard, Identities, Marketplace, Threads, Orders, Reputation

**Stack:** Vite + `vite-plugin-singlefile` for bundling into a single HTML file. Uploaded to ship via Globulator. Dev server proxies `/apps/silk/api` to the local ship.

**Files:**
- `ui/js/api.js` -- API client (GET/POST wrapper around `/apps/silk/api`)
- `ui/js/app.js` -- Application logic, rendering, event handling (603 lines)
- `ui/css/app.css` -- Styles (919 lines)
- `ui/main.js` -- Entry point
- `ui/index.html` -- Shell

Auto-refreshes data every 15 seconds.

## Desk Layout

```
desk/
  app/
    silk-core.hoon       # protocol hub + HTTP API
    silk-market.hoon     # order state machine + escrow
    silk-rep.hoon        # reputation attestations
    silk-zenith.hoon     # payment adapter
    silk.hoon            # placeholder (not part of protocol)
  sur/
    silk.hoon            # commerce protocol types
    skein.hoon           # mixnet transport types (dependency)
    skein-crypto.hoon    # crypto primitives (dependency)
    docket.hoon          # desk metadata types
    verb.hoon            # verbose logging types
  mar/
    silk-command.hoon    # silk command mark
    silk-event.hoon      # silk event mark
    skein-admin.hoon     # skein admin mark (dependency)
    skein-event.hoon     # skein event mark (dependency)
    skein-send.hoon      # skein send mark (dependency)
    bill.hoon            # base marks
    docket-0.hoon
    hoon.hoon
    kelvin.hoon
    mime.hoon
    noun.hoon
  lib/
    server.hoon          # HTTP response helpers
    dbug.hoon            # debug wrapper
    default-agent.hoon   # default agent arms
    docket.hoon          # docket helpers
    skeleton.hoon        # agent skeleton
    verb.hoon            # verbose logging
  desk.bill              # agents: silk-core, silk-rep, silk-market, silk-zenith
  desk.docket-0          # app metadata (title, glob, color)
  sys.kelvin             # zuse 409
```

## Development

### Requirements

- Urbit runtime with fakeship support
- Node.js (for frontend builds)
- `%skein` desk installed on the target ship (separate repo)

### Ships

Development uses three fakeships: `~fen`, `~nes`, `~zod`. Piers live at `~/.urbit/{ship}/`.

### Workflow

1. Edit source files locally in `desk/`
2. Copy to the mounted pier: `cp -r desk/* ~/.urbit/fen/silk/`
3. Commit in dojo: `|commit %silk`

Or use the MCP tools to `insert-file` and `commit-desk` directly.

### Frontend Build

```sh
cd ui
npm install
npm run build    # produces dist/index.html (single file)
```

Upload the built glob via Globulator or update the `glob-http` URL in `desk.docket-0`.

For development with hot reload:

```sh
npm run dev      # proxies API calls to localhost:8080
```

### Installing %skein

`%silk` depends on `%skein` being installed on the same ship. The skein types (`sur/skein.hoon`, `sur/skein-crypto.hoon`) and marks (`mar/skein-*.hoon`) are vendored into the silk desk, but the `%skein` agent itself must be running for message relay to work.

On init, `%silk-core` pokes `%skein` with `[%bind %silk-core]` to register itself as a transport endpoint.
