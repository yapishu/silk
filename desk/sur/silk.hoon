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
::  nym signing key material (crub:crypto)
::
+$  nym-keypair
  $:  pub=@ux       ::  public signing key
      sec=@ux       ::  private signing key
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
::  WS4: first-class evidence for disputes
::
+$  evidence
  $:  id=@uv
      =thread-id
      author=nym-id
      hash=@ux            ::  content hash
      note=@t
      submitted-at=@da
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
      ::  WS3: sender-aware sync deltas
      [%sync-thread-delta thread-id=@uv deltas=(list sync-delta)]
      ::  marketplace gossip — WS2: contact-first catalog sync
      [%catalog-request request-id=@uv reply-contact=@ux]
      [%catalog listings=(list listing) contacts=(list nym-contact)]
      [%listing-retracted id=listing-id]
      ::  signed nym introduction — WS2/WS6: trust bootstrap
      ::  seq: monotonic intro sequence for rotation tracking
      [%nym-intro =nym-id pubkey=@ux contact=@ux sig=@ux seq=@ud]
      ::  WS2: moderator identity introduction
      [%moderator-intro =moderator-id =nym-id pubkey=@ux contact=@ux sig=@ux]
      ::  moderator gossip
      [%moderator-profile =moderator-profile]
      [%moderator-retracted id=moderator-id]
      ::  escrow protocol
      [%escrow-propose thread-id=@uv buyer-pubkey=@ux moderator=moderator-id timeout=@dr buyer-wallet=@t]
      [%escrow-agree thread-id=@uv seller-pubkey=@ux seller-wallet=@t]
      [%escrow-funded thread-id=@uv tx-hash=@t]
      [%escrow-sign-release thread-id=@uv sig=@ux signer-idx=@ud]
      [%escrow-sign-refund thread-id=@uv sig=@ux signer-idx=@ud]
      ::  moderator notifications
      [%escrow-notify =escrow-notify-data buyer=nym-id seller=nym-id]
      [%escrow-dispute thread-id=@uv =dispute]
      [%escrow-assembled thread-id=@uv result=escrow-st tx-hex=@t]
      ::  WS4: evidence submission
      [%evidence =evidence]
  ==
::
::  moderator: trusted marketplace dispute resolver
::
+$  moderator-id  @uv
+$  moderator-profile
  $:  id=moderator-id
      =nym-id                    ::  pseudonym operating as moderator
      pubkey=@ux                 ::  secp256k1 compressed pubkey
      address=@t                 ::  zenith bech32 (derived from pubkey)
      fee-bps=@ud                ::  fee in basis points (200 = 2%)
      stake-amount=@ud           ::  claimed stake amount in sZ
      stake-sig=@ux              ::  signature of moderator-id by stake key
      description=@t
      created-at=@da
  ==
::
::  escrow: 2-of-3 multisig escrow configuration
::
+$  escrow-config
  $:  =thread-id
      buyer-pubkey=@ux
      seller-pubkey=@ux
      moderator-pubkey=@ux
      =moderator-id
      multisig-address=@t        ::  derived 2-of-3 address
      amount=@ud
      currency=@tas
      timeout=@dr                ::  auto-refund after this
      moderator-fee-bps=@ud
      account-number=@ud         ::  chain account number (0 for MVP)
      sequence=@ud               ::  chain tx sequence (0 for first tx)
      buyer-wallet=@t            ::  buyer zenith address (for refund)
      seller-wallet=@t           ::  seller zenith address (for release)
  ==
::
::  escrow-notify-data: stripped escrow info for moderator notification
::  does NOT include individual wallet addresses (privacy)
::
+$  escrow-notify-data
  $:  =thread-id
      buyer-pubkey=@ux
      seller-pubkey=@ux
      moderator-pubkey=@ux
      =moderator-id
      multisig-address=@t
      amount=@ud
      currency=@tas
      timeout=@dr
      moderator-fee-bps=@ud
  ==
::
+$  escrow-st
  $?  %proposed        ::  buyer proposed escrow + moderator
      %agreed          ::  seller agreed, multisig derived
      %funded          ::  buyer deposited, verified on chain
      %releasing       ::  collecting release signatures
      %released        ::  funds released to seller (tx broadcast)
      %refunding       ::  collecting refund signatures
      %refunded        ::  funds returned to buyer (tx broadcast)
      %confirmed       ::  tx confirmed on chain
      %disputed        ::  dispute filed, moderator involved
      %resolved        ::  moderator ruled, executing verdict
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
::  WS4: extended verdict with split amounts
::
+$  verdict
  $:  dispute-id=dispute-id
      thread-id=@uv
      ruling=ruling-kind
      note=@t
      ruled-at=@da
      buyer-share=@ud       ::  WS4: buyer payout (used for %split)
      seller-share=@ud      ::  WS4: seller payout
      moderator-share=@ud   ::  WS4: moderator payout
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
      [%cancel-thread thread-id=@uv reason=@t]
      ::  payment
      [%send-invoice =invoice]
      [%submit-payment =payment-proof]
      ::  fulfillment
      [%send-fulfillment =fulfillment]
      ::  disputes
      [%file-dispute =dispute]
      [%submit-verdict =verdict]
      [%submit-evidence =evidence]
      ::  moderators
      [%register-moderator =moderator-profile]
      [%retract-moderator id=moderator-id]
      ::  escrow
      [%propose-escrow thread-id=@uv moderator=moderator-id timeout=@dr]
      [%agree-escrow thread-id=@uv]
      [%fund-escrow thread-id=@uv tx-hash=@t]
      [%release-escrow thread-id=@uv]
      [%refund-escrow thread-id=@uv]
      [%rebroadcast-escrow thread-id=@uv]
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
      [%moderator-registered =moderator-profile]
      [%moderator-retracted id=moderator-id]
      [%escrow-proposed thread-id=@uv =escrow-config]
      [%escrow-agreed thread-id=@uv multisig-address=@t]
      [%escrow-funded thread-id=@uv]
      [%escrow-releasing thread-id=@uv]
      [%escrow-released thread-id=@uv]
      [%escrow-refunding thread-id=@uv]
      [%escrow-refunded thread-id=@uv]
      [%escrow-assembled thread-id=@uv result=escrow-st]
      [%escrow-confirmed thread-id=@uv]
      [%evidence-submitted =evidence]
  ==
::
::  destination: how to reach a pseudonym over skein
::
+$  nym-contact
  $:  =nym-id
      contact=@ux             ::  opaque skein contact-bundle
  ==
::
::  silk-envelope: transport wrapper carrying reply material
::  every outbound message includes fresh reply contact-bundle
::  so the receiver can reply without stable contact storage
::
+$  silk-packet
  $:  sender=nym-id           ::  market pseudonym of sender
      sig=@ux                 ::  ed25519 signature of (jam body)
      reply=(unit @ux)        ::  fresh reply contact-bundle
      body=silk-message
  ==
::
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
::
::  WS1: market command types for proposal-based approval flow
::
+$  market-proposal
  $%  [%propose-create =thread-id listing-id=listing-id buyer=nym-id seller=nym-id offer-id=offer-id amount=@ud currency=@tas]
      [%propose-advance =thread-id to=@tas]
      [%propose-escrow =thread-id to=@tas]
      [%propose-resolution =thread-id ruling=ruling-kind]
  ==
::
+$  market-response
  $%  [%proposal-approved proposal-id=@uv =thread-id to=@tas]
      [%proposal-rejected proposal-id=@uv =thread-id to=@tas reason=@t]
  ==
::
::  WS1: pending proposal buffer for silk-core
::  carries everything needed to commit on approval
::
+$  pending-proposal
  $:  proposal-id=@uv
      staged-thread=[tid=@uv thd=silk-thread]
      outbound-cards=(list card:agent:gall)
      event-cards=(list card:agent:gall)
      actor=nym-id
      ::  staged side-effect mutations (applied only on approval)
      staged-pending-acks=(list [@ux pending-msg-entry])
      staged-inventory=(list [listing-id @ud])
      staged-escrow-status=(list [@uv escrow-st])
      staged-escrow-sigs=(list [@uv (map @ud @ux)])
      staged-escrow-keys=(list [@uv @ux])
  ==
::
::  pending-msg-entry: ack tracking for staged proposals
::  (matches pending-msg shape but decoupled from state type)
::
+$  pending-msg-entry
  $:  msg-hash=@ux
      thread-id=@uv
      target=@ux
      msg=silk-message
      sent-at=@da
      attempts=@ud
      sender=nym-id
  ==
::
::  WS2: pending moderator delivery with preserved actor
::
+$  pending-mod-delivery
  $:  mod-id=moderator-id
      actor=nym-id
      msg=silk-message
  ==
::
::  WS3: sender-aware sync delta with cryptographic provenance
::
+$  sync-delta
  $:  sender=nym-id
      sig=@ux               ::  ed25519 signature of (jam msg) by sender
      msg=silk-message
      msg-id=@ux
  ==
::
::  WS3: zenith account type for the stable adapter contract
::
+$  zenith-account
  $:  address=@t
      pubkey=@ux
      privkey=@ux
      acc-num=@ud
      seq-num=@ud
  ==
--
