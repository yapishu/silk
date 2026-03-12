::  %silk: private commerce protocol surface
::
::  all protocol messages ride on %skein as opaque payloads.
::  %silk never does direct peer-to-peer messaging.
::
|%
::  pseudonym: a market-facing identity decoupled from ship
::
+$  nym-id  @uv
+$  pseudonym
  $:  id=nym-id
      label=@t
      pubkey=@ux
      wallet=@t             ::  zenith blockchain address
      created-at=@da
  ==
::
::  negotiation-key: short-lived per-thread ephemeral key
::
+$  nego-key
  $:  pubkey=@ux
      seckey=@ux
      thread-id=@uv
      created-at=@da
  ==
::
::  attestation: signed claim about a pseudonym
::
+$  attest-id  @uv
+$  attestation
  $:  id=attest-id
      subject=nym-id
      issuer=nym-id
      kind=attest-kind
      score=@ud
      note=@t
      issued-at=@da
      sig=@ux
  ==
::
+$  attest-kind
  $?  %completion       ::  order completed successfully
      %fulfillment      ::  seller fulfilled properly
      %payment          ::  buyer paid properly
      %dispute-fair     ::  dispute resolved fairly
      %general          ::  general reputation signal
  ==
::
::  protocol message types
::
::  these are the application-layer messages that %silk
::  exchanges over %skein.  %skein sees them as opaque blobs.
::
+$  silk-message
  $%  [%listing listing]
      [%offer offer]
      [%counter-offer offer]
      [%accept accept]
      [%reject reject]
      [%invoice invoice]
      [%payment-proof payment-proof]
      [%fulfill fulfillment]
      [%dispute dispute]
      [%verdict verdict]
      [%attest attestation]
      [%complete thread-id=@uv completed-at=@da]
      [%direct-message thread-id=@uv listing-id=listing-id sender=nym-id text=@t sent-at=@da]
      ::  delivery acknowledgment
      [%ack thread-id=@uv msg-hash=@ux acked-at=@da]
      ::  thread reconciliation
      [%sync-thread thread-id=@uv chain=@ux msg-count=@ud]
      [%sync-thread-response =silk-thread]
      ::  keepalive
      [%ping thread-id=@uv]
      [%pong thread-id=@uv]
      ::  marketplace gossip
      [%catalog-request from-ship=@p]
      [%catalog listings=(list listing) routes=(list nym-route)]
      [%listing-retracted id=listing-id]
  ==
::
::  listing: a storefront advertisement
::
+$  listing-id  @uv
+$  listing
  $:  id=listing-id
      seller=nym-id
      title=@t
      description=@t
      price=@ud          ::  in smallest denomination
      currency=@tas       ::  e.g. %usd, %eth, %zen
      created-at=@da
      expires-at=(unit @da)
  ==
::
::  offer / counter-offer
::
+$  offer-id  @uv
+$  offer
  $:  id=offer-id
      thread-id=@uv
      listing-id=listing-id
      buyer=nym-id
      seller=nym-id
      amount=@ud
      currency=@tas
      note=@t
      offered-at=@da
  ==
::
::  accept / reject
::
+$  accept
  $:  thread-id=@uv
      offer-id=offer-id
      accepted-at=@da
  ==
::
+$  reject
  $:  thread-id=@uv
      offer-id=offer-id
      reason=@t
      rejected-at=@da
  ==
::
::  invoice and payment
::
+$  invoice-id  @uv
+$  invoice
  $:  id=invoice-id
      thread-id=@uv
      offer-id=offer-id
      seller=nym-id
      amount=@ud
      currency=@tas
      pay-address=@t      ::  zenith address or external
      expires-at=@da
  ==
::
+$  payment-proof
  $:  thread-id=@uv
      invoice-id=invoice-id
      tx-hash=@t              ::  chain transaction hash (string)
      paid-at=@da
  ==
::
::  fulfillment
::
+$  fulfillment
  $:  thread-id=@uv
      offer-id=offer-id
      note=@t
      payload=*            ::  opaque delivery content
      fulfilled-at=@da
  ==
::
::  disputes
::
+$  dispute-id  @uv
+$  dispute
  $:  id=dispute-id
      thread-id=@uv
      offer-id=offer-id
      plaintiff=nym-id
      reason=@t
      evidence=*
      filed-at=@da
  ==
::
+$  verdict
  $:  dispute-id=dispute-id
      thread-id=@uv
      ruling=ruling-kind
      note=@t
      ruled-at=@da
  ==
::
+$  ruling-kind
  $?  %buyer-wins
      %seller-wins
      %split
      %dismissed
  ==
::
::  thread: tracks a negotiation conversation
::
+$  thread-id  @uv
::  chain: running hash of all state transitions.
::  each step hashes [prev-chain message-tag] creating a
::  tamper-evident log.  if either party skips or alters
::  a step, the chain diverges and reconciliation detects it.
::
+$  silk-thread
  $:  id=thread-id
      listing-id=listing-id
      buyer=nym-id
      seller=nym-id
      =thread-status
      messages=(list silk-message)
      chain=@ux
      started-at=@da
      updated-at=@da
  ==
::
+$  thread-status
  $?  %open           ::  negotiation in progress
      %accepted       ::  offer accepted, awaiting payment
      %paid           ::  payment submitted
      %fulfilled      ::  seller delivered
      %completed      ::  both sides satisfied
      %disputed       ::  dispute filed
      %resolved       ::  dispute resolved
      %cancelled      ::  cancelled by either party
  ==
::
::  commands to the silk-core agent
::
+$  silk-command
  $%  ::  pseudonym management
      [%create-nym label=@t wallet=@t]
      [%drop-nym id=nym-id]
      ::  listing management
      [%post-listing =listing]
      [%retract-listing id=listing-id]
      ::  marketplace peers
      [%add-peer ship=@p]
      [%drop-peer ship=@p]
      [%sync-catalog ~]
      ::  negotiation
      [%send-offer =offer]
      [%accept-offer thread-id=@uv offer-id=offer-id]
      [%reject-offer thread-id=@uv offer-id=offer-id reason=@t]
      ::  payment
      [%send-invoice =invoice]
      [%submit-payment =payment-proof]
      ::  fulfillment
      [%send-fulfillment =fulfillment]
      ::  disputes
      [%file-dispute =dispute]
      [%submit-verdict =verdict]
  ==
::
::  events from silk-core
::
+$  silk-event
  $%  [%nym-created =pseudonym]
      [%nym-dropped id=nym-id]
      [%listing-posted =listing]
      [%listing-retracted id=listing-id]
      [%thread-opened =silk-thread]
      [%thread-updated id=thread-id =thread-status]
      [%message-received thread-id=@uv =silk-message]
      [%attestation-received =attestation]
      [%peer-added ship=@p]
      [%peer-removed ship=@p]
      [%catalog-received count=@ud]
  ==
::
::  destination: how to reach a pseudonym over skein
::
+$  nym-route
  $:  =nym-id
      target-ship=@p          ::  skein endpoint ship
      target-app=@tas          ::  skein endpoint app (always %silk-core)
  ==
::
::  rep commands
::
+$  rep-command
  $%  [%issue =attestation]
      [%revoke id=attest-id]
      [%import =attestation]
  ==
::
+$  rep-event
  $%  [%issued =attestation]
      [%revoked id=attest-id]
      [%imported =attestation]
      [%score-updated subject=nym-id score=@ud]
  ==
--
