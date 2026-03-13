::  %silk-core: private commerce protocol agent
::
::  all peer messaging goes through %skein.
::  this agent never does direct ship-to-ship communication.
::  serves HTTP JSON API at /apps/silk/api/ for the frontend.
::
/-  *silk
/+  dbug, verb, default-agent, server, multisig
|%
::  old types for state migration
+$  pseudonym-v0
  $:  id=nym-id
      label=@t
      pubkey=@ux
      created-at=@da
  ==
+$  thread-v2
  $:  id=thread-id
      listing-id=listing-id
      buyer=nym-id
      seller=nym-id
      =thread-status
      messages=(list silk-message)
      started-at=@da
      updated-at=@da
  ==
+$  state-0
  $:  %0
      nyms=(map nym-id pseudonym-v0)
      listings=(map listing-id listing)
      threads=(map thread-id thread-v2)
      routes=(map nym-id nym-route)
      next-seq=@ud
  ==
::
+$  state-1
  $:  %1
      nyms=(map nym-id pseudonym-v0)
      listings=(map listing-id listing)
      threads=(map thread-id thread-v2)
      routes=(map nym-id nym-route)
      peers=(set @p)
      next-seq=@ud
  ==
::
+$  state-2
  $:  %2
      nyms=(map nym-id pseudonym-v0)
      listings=(map listing-id listing)
      threads=(map thread-id thread-v2)
      routes=(map nym-id nym-route)
      peers=(set @p)
      attestations=(map attest-id attestation)
      next-seq=@ud
  ==
::
+$  state-3
  $:  %3
      nyms=(map nym-id pseudonym-v0)
      listings=(map listing-id listing)
      threads=(map thread-id silk-thread)
      routes=(map nym-id nym-route)
      peers=(set @p)
      attestations=(map attest-id attestation)
      next-seq=@ud
  ==
::
+$  state-4
  $:  %4
      nyms=(map nym-id pseudonym)
      listings=(map listing-id listing)
      threads=(map thread-id silk-thread)
      routes=(map nym-id nym-route)
      peers=(set @p)
      attestations=(map attest-id attestation)
      ::  zenith verification: thread-id -> [verified balance checked-at]
      verifications=(map thread-id [verified=? balance=@ud checked-at=@da])
      next-seq=@ud
  ==
::
+$  pending-msg
  $:  msg-hash=@ux
      thread-id=@uv
      target=nym-route
      msg=silk-message
      sent-at=@da
      attempts=@ud
  ==
::
+$  state-5
  $:  %5
      nyms=(map nym-id pseudonym)
      listings=(map listing-id listing)
      threads=(map thread-id silk-thread)
      routes=(map nym-id nym-route)
      peers=(set @p)
      attestations=(map attest-id attestation)
      verifications=(map thread-id [verified=? balance=@ud checked-at=@da])
      next-seq=@ud
      keys=(map nym-id nym-keypair)
      pending-acks=(map @ux pending-msg)  ::  msg-hash -> pending
  ==
::
+$  state-6
  $:  %6
      nyms=(map nym-id pseudonym)
      listings=(map listing-id listing)
      threads=(map thread-id silk-thread)
      routes=(map nym-id nym-route)
      peers=(set @p)
      attestations=(map attest-id attestation)
      verifications=(map thread-id [verified=? balance=@ud checked-at=@da])
      next-seq=@ud
      keys=(map nym-id nym-keypair)
      pending-acks=(map @ux pending-msg)
      inventory=(map listing-id @ud)  ::  0 or absent = unlimited
  ==
::
+$  state-7
  $:  %7
      nyms=(map nym-id pseudonym)
      listings=(map listing-id listing)
      threads=(map thread-id silk-thread)
      routes=(map nym-id nym-route)
      peers=(set @p)
      attestations=(map attest-id attestation)
      verifications=(map thread-id [verified=? balance=@ud checked-at=@da])
      next-seq=@ud
      keys=(map nym-id nym-keypair)
      pending-acks=(map @ux pending-msg)
      inventory=(map listing-id @ud)
      ::  moderator directory (gossiped)
      moderators=(map moderator-id moderator-profile)
      ::  escrow state per thread
      escrows=(map thread-id escrow-config)
      escrow-status=(map thread-id escrow-st)
      escrow-sigs=(map thread-id (map @ud @ux))
      escrow-keys=(map thread-id @ux)  ::  our per-tx private key
  ==
::
+$  state-8
  $:  %8
      nyms=(map nym-id pseudonym)
      listings=(map listing-id listing)
      threads=(map thread-id silk-thread)
      routes=(map nym-id nym-route)
      peers=(set @p)
      attestations=(map attest-id attestation)
      verifications=(map thread-id [verified=? balance=@ud checked-at=@da])
      next-seq=@ud
      keys=(map nym-id nym-keypair)
      pending-acks=(map @ux pending-msg)
      inventory=(map listing-id @ud)
      moderators=(map moderator-id moderator-profile)
      escrows=(map thread-id escrow-config)
      escrow-status=(map thread-id escrow-st)
      escrow-sigs=(map thread-id (map @ud @ux))
      escrow-keys=(map thread-id @ux)
      mod-keys=(map moderator-id @ux)     ::  moderator private keys
      escrow-txhex=(map thread-id @t)     ::  assembled broadcast-ready tx hex
  ==
::
+$  current-state  state-8
+$  card  card:agent:gall
::
++  max-resend   3          ::  max resend attempts
++  resend-base  ~m1        ::  base backoff for resends
++  resend-period  ~m2      ::  how often to check pending acks
::
++  skein-app  %silk-core
::
++  skein-send-card
  |=  [our=ship target=nym-route msg=silk-message]
  ^-  card
  =/  req
    :*  skein-app
        [target-ship.target target-app.target]
        (jam msg)
        [~ ~ ~]
    ==
  [%pass /silk/send %agent [our %skein] %poke %skein-send !>(req)]
::
++  gossip-card
  |=  [our=ship target-ship=@p msg=silk-message]
  ^-  card
  =/  req
    :*  skein-app
        [target-ship %silk-core]
        (jam msg)
        [~ ~ ~]
    ==
  [%pass /silk/gossip %agent [our %skein] %poke %skein-send !>(req)]
::
++  event-card
  |=  ev=silk-event
  ^-  card
  [%give %fact [/events]~ %silk-event !>(ev)]
::
::  track a sent protocol message for ack-based resend
::
++  make-pending
  |=  [tid=@uv target=nym-route msg=silk-message now=@da]
  ^-  [hash=@ux pm=pending-msg]
  =/  hash=@ux  `@ux`(sham msg)
  [hash [hash tid target msg now 0]]
::
::  poke silk-market to create or advance an order
::
++  market-create-card
  |=  [our=ship tid=@uv lid=listing-id buyer=nym-id seller=nym-id oid=offer-id amount=@ud currency=@tas]
  ^-  card
  [%pass /market/create %agent [our %silk-market] %poke %noun !>([%create-order tid lid buyer seller oid amount currency])]
::
++  market-advance-card
  |=  [our=ship tid=@uv to=@tas]
  ^-  card
  [%pass /market/advance %agent [our %silk-market] %poke %noun !>([%advance tid to])]
::
::  poke silk-zenith for invoice and payment operations
::
++  zenith-invoice-card
  |=  [our=ship tid=@uv amount=@ud currency=@tas seller-nym=nym-id]
  ^-  card
  [%pass /zenith/invoice %agent [our %silk-zenith] %poke %noun !>([%create-invoice tid amount currency seller-nym])]
::
++  zenith-payment-card
  |=  [our=ship inv-id=invoice-id tx-hash=@ux]
  ^-  card
  [%pass /zenith/payment %agent [our %silk-zenith] %poke %noun !>([%record-payment inv-id tx-hash])]
::
++  give-http
  |=  [eyre-id=@ta status=@ud headers=(list [@t @t]) body=(unit octs)]
  ^-  (list card)
  %+  give-simple-payload:app:server  eyre-id
  [[status headers] body]
::
::  compute chain hash from a message list (stored newest-first)
::
++  compute-chain
  |=  msgs=(list silk-message)
  ^-  @ux
  =/  ordered=(list silk-message)  (flop msgs)
  =/  h=@ux  `@ux`0
  |-
  ?~  ordered  h
  $(ordered t.ordered, h `@ux`(sham [h -.i.ordered]))
::
::  advance chain by one step
::
++  advance-chain
  |=  [prev=@ux tag=@tas]
  ^-  @ux
  `@ux`(sham [prev tag])
::
++  find-offer
  |=  msgs=(list silk-message)
  ^-  (unit offer)
  ?~  msgs  ~
  ?:  ?=(%offer -.i.msgs)  `+.i.msgs
  $(msgs t.msgs)
::
++  find-invoice
  |=  msgs=(list silk-message)
  ^-  (unit invoice)
  ?~  msgs  ~
  ?:  ?=(%invoice -.i.msgs)  `+.i.msgs
  $(msgs t.msgs)
::
::  migrate v0 pseudonym (no wallet) to current (with wallet)
::
++  migrate-nym
  |=  n=pseudonym-v0
  ^-  pseudonym
  [id.n label.n pubkey.n '' created-at.n]
::
::  migrate v2 thread (no chain) to v3 thread (with chain)
::
++  migrate-thread
  |=  t=thread-v2
  ^-  silk-thread
  [id.t listing-id.t buyer.t seller.t thread-status.t messages.t (compute-chain messages.t) started-at.t updated-at.t]
::
++  give-json
  |=  [eyre-id=@ta jon=json]
  ^-  (list card)
  %+  give-simple-payload:app:server  eyre-id
  (json-response:gen:server jon)
--
::
%+  verb  |
%-  agent:dbug
=|  current-state
=*  state  -
^-  agent:gall
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %|) bowl)
::
++  on-init
  ^-  (quip card _this)
  :_  this
  :~  [%pass /silk/bind %agent [our.bowl %skein] %poke %skein-admin !>([%bind skein-app])]
      [%pass /silk/channel %agent [our.bowl %skein] %poke %skein-admin !>([%join-channel %silk-market %silk-core])]
      [%pass /eyre/connect %arvo %e %connect [~ /apps/silk/api] %silk-core]
      ::  subscribe to market and zenith event feeds
      [%pass /market/events %agent [our.bowl %silk-market] %watch /market-events]
      [%pass /zenith/events %agent [our.bowl %silk-zenith] %watch /zenith-events]
      ::  resend timer for pending acks
      [%pass /silk/resend %arvo %b %wait (add now.bowl resend-period)]
  ==
::
++  on-save
  !>(state)
::
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  ~&  [%silk-core %on-load %starting]
  ::  leave stale subscriptions before re-subscribing (prevents wire-not-unique)
  =/  leave-cards=(list card)
    =/  acc=(list card)  ~
    =?  acc  (~(has by wex.bowl) [/market/events our.bowl %silk-market])
      [[%pass /market/events %agent [our.bowl %silk-market] %leave ~] acc]
    =?  acc  (~(has by wex.bowl) [/zenith/events our.bowl %silk-zenith])
      [[%pass /zenith/events %agent [our.bowl %silk-zenith] %leave ~] acc]
    acc
  =/  load-cards=(list card)
    :~  [%pass /eyre/connect %arvo %e %connect [~ /apps/silk/api] %silk-core]
        [%pass /silk/bind %agent [our.bowl %skein] %poke %skein-admin !>([%bind skein-app])]
        [%pass /silk/channel %agent [our.bowl %skein] %poke %skein-admin !>([%join-channel %silk-market %silk-core])]
        ::  subscribe to market and zenith event feeds
        [%pass /market/events %agent [our.bowl %silk-market] %watch /market-events]
        [%pass /zenith/events %agent [our.bowl %silk-zenith] %watch /zenith-events]
        ::  resend timer for pending acks
        [%pass /silk/resend %arvo %b %wait (add now.bowl resend-period)]
    ==
  ~&  [%silk-core %on-load %bootstrap-cards (lent leave-cards) %leave (lent load-cards) %load]
  =/  load-cards  (weld leave-cards load-cards)
  =/  try-8  (mule |.(;;(state-8 q.old)))
  ?:  ?=(%& -.try-8)
    =.  state  p.try-8
    [load-cards this]
  =/  try-7  (mule |.(;;(state-7 q.old)))
  ?:  ?=(%& -.try-7)
    ::  migrate escrow-config: add account-number, sequence, wallets
    =/  new-escrows=(map thread-id escrow-config)
      %-  ~(run by escrows.p.try-7)
      |=  esc=*
      =/  old  ;;([thread-id=@uv buyer-pubkey=@ux seller-pubkey=@ux moderator-pubkey=@ux moderator-id=@uv multisig-address=@t amount=@ud currency=@tas timeout=@dr moderator-fee-bps=@ud] esc)
      ^-  escrow-config
      :*  thread-id.old  buyer-pubkey.old  seller-pubkey.old
          moderator-pubkey.old  moderator-id.old  multisig-address.old
          amount.old  currency.old  timeout.old  moderator-fee-bps.old
          0  0  ''  ''  ::  account-number, sequence, buyer-wallet, seller-wallet
      ==
    =.  state
      :*  %8
          nyms.p.try-7  listings.p.try-7  threads.p.try-7
          routes.p.try-7  peers.p.try-7  attestations.p.try-7
          verifications.p.try-7  next-seq.p.try-7
          keys.p.try-7  pending-acks.p.try-7
          inventory.p.try-7  moderators.p.try-7
          new-escrows
          escrow-status.p.try-7  escrow-sigs.p.try-7
          escrow-keys.p.try-7
          ~  ~  ::  mod-keys, escrow-txhex
      ==
    [load-cards this]
  =/  try-6  (mule |.(;;(state-6 q.old)))
  ?:  ?=(%& -.try-6)
    =.  state
      :*  %8
          nyms.p.try-6  listings.p.try-6  threads.p.try-6
          routes.p.try-6  peers.p.try-6  attestations.p.try-6
          verifications.p.try-6  next-seq.p.try-6
          keys.p.try-6  pending-acks.p.try-6
          inventory.p.try-6
          ~  ~  ~  ~  ~  ~  ~  ::  moderators, escrows, escrow-status, escrow-sigs, escrow-keys, mod-keys, escrow-txhex
      ==
    [load-cards this]
  =/  try-5  (mule |.(;;(state-5 q.old)))
  ?:  ?=(%& -.try-5)
    =.  state
      :*  %8
          nyms.p.try-5  listings.p.try-5  threads.p.try-5
          routes.p.try-5  peers.p.try-5  attestations.p.try-5
          verifications.p.try-5  next-seq.p.try-5
          keys.p.try-5  pending-acks.p.try-5
          ~  ::  inventory
          ~  ~  ~  ~  ~  ~  ~  ::  moderators, escrows, escrow-status, escrow-sigs, escrow-keys, mod-keys, escrow-txhex
      ==
    [load-cards this]
  =/  try-4  (mule |.(;;(state-4 q.old)))
  ?:  ?=(%& -.try-4)
    =.  state
      :*  %8
          nyms.p.try-4  listings.p.try-4  threads.p.try-4
          routes.p.try-4  peers.p.try-4  attestations.p.try-4
          verifications.p.try-4  next-seq.p.try-4
          ~    ::  keys
          ~    ::  pending-acks
          ~    ::  inventory
          ~  ~  ~  ~  ~  ~  ~  ::  moderators, escrows, escrow-status, escrow-sigs, escrow-keys, mod-keys, escrow-txhex
      ==
    [load-cards this]
  =/  try-3  (mule |.(;;(state-3 q.old)))
  ?:  ?=(%& -.try-3)
    =.  state
      :*  %8
          (~(run by nyms.p.try-3) migrate-nym)
          listings.p.try-3  threads.p.try-3
          routes.p.try-3  peers.p.try-3
          attestations.p.try-3  ~  next-seq.p.try-3  ~  ~  ~
          ~  ~  ~  ~  ~  ~  ~  ::  moderators, escrows, escrow-status, escrow-sigs, escrow-keys, mod-keys, escrow-txhex
      ==
    [load-cards this]
  =/  try-2  (mule |.(;;(state-2 q.old)))
  ?:  ?=(%& -.try-2)
    =.  state
      :*  %8
          (~(run by nyms.p.try-2) migrate-nym)
          listings.p.try-2
          (~(run by threads.p.try-2) migrate-thread)
          routes.p.try-2  peers.p.try-2
          attestations.p.try-2  ~  next-seq.p.try-2  ~  ~  ~
          ~  ~  ~  ~  ~  ~  ~  ::  moderators, escrows, escrow-status, escrow-sigs, escrow-keys, mod-keys, escrow-txhex
      ==
    [load-cards this]
  =/  try-1  (mule |.(;;(state-1 q.old)))
  ?:  ?=(%& -.try-1)
    =.  state
      :*  %8
          (~(run by nyms.p.try-1) migrate-nym)
          listings.p.try-1
          (~(run by threads.p.try-1) migrate-thread)
          routes.p.try-1  peers.p.try-1  ~  ~  next-seq.p.try-1  ~  ~  ~
          ~  ~  ~  ~  ~  ~  ~  ::  moderators, escrows, escrow-status, escrow-sigs, escrow-keys, mod-keys, escrow-txhex
      ==
    [load-cards this]
  =/  try-0  (mule |.(;;(state-0 q.old)))
  ?:  ?=(%& -.try-0)
    =.  state
      :*  %8
          (~(run by nyms.p.try-0) migrate-nym)
          listings.p.try-0
          (~(run by threads.p.try-0) migrate-thread)
          routes.p.try-0  ~  ~  ~  next-seq.p.try-0  ~  ~  ~
          ~  ~  ~  ~  ~  ~  ~  ::  moderators, escrows, escrow-status, escrow-sigs, escrow-keys, mod-keys, escrow-txhex
      ==
    [load-cards this]
  =.  state  [%8 ~ ~ ~ ~ ~ ~ ~ 1 ~ ~ ~ ~ ~ ~ ~ ~ ~ ~]
  [load-cards this]
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  |^
  ?+  mark  (on-poke:def mark vase)
      %handle-http-request
    =+  !<([eyre-id=@ta req=inbound-request:eyre] vase)
    (handle-http eyre-id req)
  ::
      %silk-command
    ?>  =(our src):bowl
    =/  cmd  !<(silk-command vase)
    (handle-command cmd)
  ::
      %noun
    =/  raw  q.vase
    ::  debug dump
    ?:  ?=(%debug-escrow raw)
      ~&  '--- ESCROW DEBUG DUMP ---'
      ~&  [%escrows ~(wyt by escrows.state)]
      ~&  [%escrow-status ~(wyt by escrow-status.state)]
      ~&  [%escrow-sigs ~(wyt by escrow-sigs.state)]
      ~&  [%escrow-keys ~(wyt by escrow-keys.state)]
      ~&  [%mod-keys ~(wyt by mod-keys.state)]
      ~&  [%moderators ~(wyt by moderators.state)]
      ~&  [%escrow-txhex ~(wyt by escrow-txhex.state)]
      =/  esc-list=(list [@uv escrow-config])  ~(tap by escrows.state)
      |-
      ?~  esc-list
        ~&  '--- END ESCROW DEBUG ---'
        `this
      =/  [tid=@uv esc=escrow-config]  i.esc-list
      =/  est=(unit escrow-st)  (~(get by escrow-status.state) tid)
      =/  sigs=(map @ud @ux)  (~(gut by escrow-sigs.state) tid ~)
      ~&  :*  %esc-entry
              %tid  (scot %uv tid)
              %status  ?~(est %none u.est)
              %sigs  ~(wyt by sigs)
              %has-key  (~(has by escrow-keys.state) tid)
              %multisig  multisig-address.esc
              %mod-id  (scot %uv moderator-id.esc)
              %buyer-pk  ?:(=(0x0 buyer-pubkey.esc) %empty %set)
              %seller-pk  ?:(=(0x0 seller-pubkey.esc) %empty %set)
          ==
      $(esc-list t.esc-list)
    ::  set escrow account info (from silk-zenith query)
    ?:  ?=([%set-escrow-account @ @ @] raw)
      =/  [* tid=@uv acc-num=@ud seq-num=@ud]  raw
      =/  esc=(unit escrow-config)  (~(get by escrows.state) tid)
      ?~  esc
        ~&  [%silk-escrow %set-account-no-escrow tid]
        `this
      ~&  [%silk-escrow %set-account tid %acc-num acc-num %seq seq-num]
      =/  updated=escrow-config  u.esc(account-number acc-num, sequence seq-num)
      =.  escrows.state  (~(put by escrows.state) tid updated)
      ::  if escrow was trying to sign but blocked on account info, retry now
      ::  skip if tx already assembled (broadcast already happened)
      ?:  !=('' (~(gut by escrow-txhex.state) tid ''))
        ~&  [%silk-escrow %set-account-skip-already-broadcast tid]
        `this
      =/  st=(unit escrow-st)  (~(get by escrow-status.state) tid)
      ?+  st  `this
          [~ %releasing]
        ~&  [%silk-escrow %retry-release-with-account tid]
        =.  escrow-sigs.state  (~(put by escrow-sigs.state) tid ~)
        =.  escrow-status.state  (~(put by escrow-status.state) tid %funded)
        (handle-command [%release-escrow tid])
      ::
          [~ %refunding]
        ~&  [%silk-escrow %retry-refund-with-account tid]
        =.  escrow-sigs.state  (~(put by escrow-sigs.state) tid ~)
        =.  escrow-status.state  (~(put by escrow-status.state) tid %funded)
        (handle-command [%refund-escrow tid])
      ==
    ::  channel peer notifications from skein
    ?:  ?=([%channel-join @ @] raw)
      =/  [* channel=@tas ship=@p]  raw
      ?:  =(ship our.bowl)  `this
      ?:  (~(has in peers.state) ship)  `this
      ~&  [%silk-channel %peer-join channel ship]
      =.  peers.state  (~(put in peers.state) ship)
      ~&  [%silk-channel %peer-saved ship %total ~(wyt in peers.state)]
      =/  our-listings=(list listing)  ~(val by listings.state)
      =/  our-routes=(list nym-route)
        %+  turn  ~(val by nyms.state)
        |=(n=pseudonym [id.n our.bowl %silk-core])
      =/  mod-cards=(list card)
        %+  turn  ~(val by moderators.state)
        |=(mp=moderator-profile (gossip-card our.bowl ship [%moderator-profile mp]))
      :_  this
      ;:  weld
        [(event-card [%peer-added ship])]~
        [(gossip-card our.bowl ship [%catalog our-listings our-routes])]~
        mod-cards
      ==
    ?:  ?=([%channel-members @ *] raw)
      =/  [* channel=@tas ships=*]  raw
      =/  peer-list  (mule |.(((list @p) ships)))
      ?.  ?=(%& -.peer-list)  `this
      =/  peers=(list @p)  p.peer-list
      ~&  [%silk-channel %members channel (lent peers) %ships peers]
      =/  new-peers=(list @p)
        %+  murn  peers
        |=(p=@p ?:(|(=(p our.bowl) (~(has in peers.state) p)) ~ `p))
      =.  peers.state
        |-
        ?~  new-peers  peers.state
        $(new-peers t.new-peers, peers.state (~(put in peers.state) i.new-peers))
      =/  peer-cards=(list card)
        (turn new-peers |=(p=@p (event-card [%peer-added p])))
      =/  our-listings=(list listing)  ~(val by listings.state)
      =/  our-routes=(list nym-route)
        %+  turn  ~(val by nyms.state)
        |=(n=pseudonym [id.n our.bowl %silk-core])
      =/  catalog-cards=(list card)
        (turn new-peers |=(p=@p (gossip-card our.bowl p [%catalog our-listings our-routes])))
      =/  mod-cards=(list card)
        %-  zing
        %+  turn  new-peers
        |=  p=@p
        %+  turn  ~(val by moderators.state)
        |=(mp=moderator-profile (gossip-card our.bowl p [%moderator-profile mp]))
      [;:(weld peer-cards catalog-cards mod-cards) this]
    ?:  ?=([%channel-leave @ @] raw)
      =/  [* channel=@tas ship=@p]  raw
      ~&  [%silk-channel %peer-leave channel ship]
      `this
    ::  inbound skein delivery (opaque payload -> silk-message)
    ?.  ?=(@ raw)
      ::  try to parse as silk-command (e.g. from MCP noun pokes)
      =/  cmd-try  (mule |.((silk-command raw)))
      ?:  ?=(%& -.cmd-try)
        ?>  =(our src):bowl
        (handle-command p.cmd-try)
      ~&  [%silk-core %noun-not-atom]
      `this
    =/  parsed  (mule |.((silk-message (cue raw))))
    ?:  ?=(%| -.parsed)
      ~&  [%silk-core %noun-parse-fail]
      `this
    =/  msg=silk-message  p.parsed
    ::  gossip messages
    ?:  ?=(%listing -.msg)
      ~&  [%silk-gossip %listing-received id.+.msg]
      ?:  (~(has by listings.state) id.+.msg)  `this
      =.  listings.state  (~(put by listings.state) id.+.msg +.msg)
      :-  [(event-card [%listing-posted +.msg])]~
      this
    ?:  ?=(%catalog-request -.msg)
      ~&  [%silk-gossip %catalog-request-from from-ship.msg]
      =/  ship=@p  from-ship.msg
      ?:  =(ship our.bowl)  `this
      ::  auto-peer: add requester so future listings push to them
      =/  new-peer=?  !(~(has in peers.state) ship)
      =.  peers.state  (~(put in peers.state) ship)
      =/  our-listings=(list listing)  ~(val by listings.state)
      =/  our-routes=(list nym-route)
        %+  turn  ~(val by nyms.state)
        |=(n=pseudonym [id.n our.bowl %silk-core])
      ~&  [%silk-gossip %sending-catalog (lent our-listings) %listings-to ship]
      =/  mod-cards=(list card)
        %+  turn  ~(val by moderators.state)
        |=(mp=moderator-profile (gossip-card our.bowl ship [%moderator-profile mp]))
      :_  this
      ;:  weld
        [(gossip-card our.bowl ship [%catalog our-listings our-routes])]~
        mod-cards
        ?:(new-peer [(event-card [%peer-added ship])]~ ~)
      ==
    ?:  ?=(%catalog -.msg)
      =/  new-count=@ud  0
      =.  listings.state
        =/  lsts=(list listing)  listings.msg
        |-
        ?~  lsts  listings.state
        ?:  (~(has by listings.state) id.i.lsts)
          $(lsts t.lsts)
        ~&  [%silk-gossip %new-listing id.i.lsts title.i.lsts]
        $(lsts t.lsts, listings.state (~(put by listings.state) id.i.lsts i.lsts))
      =.  routes.state
        =/  rtes=(list nym-route)  routes.msg
        |-
        ?~  rtes  routes.state
        $(rtes t.rtes, routes.state (~(put by routes.state) nym-id.i.rtes i.rtes))
      ~&  [%silk-gossip %catalog-received (lent listings.msg) %listings (lent routes.msg) %routes]
      :-  [(event-card [%catalog-received (lent listings.msg)])]~
      this
    ::  non-thread messages
    ?:  ?=(%attest -.msg)
      =/  att=attestation  +.msg
      =.  attestations.state  (~(put by attestations.state) id.att att)
      :_  this
      :~  [%pass /silk/rep %agent [our.bowl %silk-rep] %poke %noun !>([%import att])]
          (event-card [%attestation-received att])
      ==
    ?:  ?=(%listing-retracted -.msg)
      ~&  [%silk-gossip %listing-retracted id.+.msg]
      =.  listings.state  (~(del by listings.state) id.+.msg)
      :-  [(event-card [%listing-retracted id.+.msg])]~
      this
    ::  moderator gossip
    ?:  ?=(%moderator-profile -.msg)
      =/  mp=moderator-profile  +.msg
      ?:  (~(has by moderators.state) id.mp)  `this
      =.  moderators.state  (~(put by moderators.state) id.mp mp)
      ::  re-send escrow-notify for any escrows with this moderator
      ::  (catches up moderators who joined/rejoined after escrow was agreed)
      =/  resend-cards=(list card)
        %-  zing
        %+  murn  ~(tap by escrows.state)
        |=  [tid=@uv esc=escrow-config]
        ?.  =(moderator-id.esc id.mp)  ~
        =/  thd=(unit silk-thread)  (~(get by threads.state) tid)
        ?~  thd  ~
        =/  notify=silk-message  [%escrow-notify esc buyer.u.thd seller.u.thd]
        ::  send via direct route if we have it, AND gossip to all peers
        =/  mod-route=(unit nym-route)  (~(get by routes.state) nym-id.mp)
        =/  direct=(list card)
          ?~  mod-route  ~
          [(skein-send-card our.bowl u.mod-route notify)]~
        =/  gpeers=(list @p)
          %+  murn  ~(tap in peers.state)
          |=(p=@p ?:(=(p our.bowl) ~ `p))
        =/  gossip=(list card)
          (turn gpeers |=(p=@p (gossip-card our.bowl p notify)))
        `(weld direct gossip)
      ~&  [%silk-moderator %profile-received id.mp %resend-escrows (lent resend-cards)]
      :-  (weld [(event-card [%moderator-registered mp])]~ resend-cards)
      this
    ?:  ?=(%moderator-retracted -.msg)
      =.  moderators.state  (~(del by moderators.state) id.+.msg)
      :-  [(event-card [%moderator-retracted id.+.msg])]~
      this
    ::  escrow protocol messages
    ?:  ?=(%escrow-propose -.msg)
      =/  tid=@uv  thread-id.msg
      =/  thd=(unit silk-thread)  (~(get by threads.state) tid)
      ?~  thd  `this
      =/  mod=(unit moderator-profile)  (~(get by moderators.state) moderator.msg)
      ?~  mod  `this  ::  unknown moderator, drop
      ::  reject if moderator is buyer or seller
      ?:  =(nym-id.u.mod buyer.u.thd)  `this
      ?:  =(nym-id.u.mod seller.u.thd)  `this
      ::  extract offer amount from thread messages
      =/  off=(unit offer)
        =/  ms=(list silk-message)  messages.u.thd
        |-
        ?~  ms  ~
        ?:  ?=(%offer -.i.ms)  `+.i.ms
        $(ms t.ms)
      ?~  off  `this
      ::  store escrow config on seller side
      ::  buyer-wallet comes from the message; seller-wallet from our local nym
      =/  seller-nym=(unit pseudonym)  (~(get by nyms.state) seller.u.thd)
      =/  esc=escrow-config
        :*  tid
            buyer-pubkey.msg         ::  buyer's per-tx pubkey
            0x0                      ::  seller-pubkey (filled on agree)
            pubkey.u.mod             ::  moderator-pubkey
            id.u.mod                 ::  moderator-id
            ''                       ::  multisig-address (derived on agree)
            amount.u.off
            currency.u.off
            timeout.msg
            fee-bps.u.mod
            0                        ::  account-number
            0                        ::  sequence
            buyer-wallet.msg
            ?~(seller-nym '' wallet.u.seller-nym)
        ==
      =.  escrows.state  (~(put by escrows.state) tid esc)
      =.  escrow-status.state  (~(put by escrow-status.state) tid %proposed)
      =/  market-cards=(list card)
        [(market-advance-card our.bowl tid %escrow-proposed)]~
      :-  (weld [(event-card [%message-received tid msg])]~ market-cards)
      this
    ?:  ?=(%escrow-agree -.msg)
      =/  tid=@uv  thread-id.msg
      =/  esc=(unit escrow-config)  (~(get by escrows.state) tid)
      ?~  esc  `this
      ::  derive real 2-of-3 multisig address; fill seller-wallet from message
      =/  addr=@t  (derive-multisig-address:multisig ~[buyer-pubkey.u.esc seller-pubkey.msg moderator-pubkey.u.esc])
      =/  updated=escrow-config
        u.esc(seller-pubkey seller-pubkey.msg, multisig-address addr, seller-wallet seller-wallet.msg)
      =.  escrows.state  (~(put by escrows.state) tid updated)
      =.  escrow-status.state  (~(put by escrow-status.state) tid %agreed)
      =/  market-cards=(list card)
        [(market-advance-card our.bowl tid %escrow-agreed)]~
      ::  buyer also sends escrow-notify directly to moderator (redundant with seller)
      ::  buyer also notifies moderator: direct + gossip
      =/  thd-for-notify=(unit silk-thread)  (~(get by threads.state) tid)
      =/  notify-cards=(list card)
        ?~  thd-for-notify  ~
        =/  notify-msg=silk-message  [%escrow-notify updated buyer.u.thd-for-notify seller.u.thd-for-notify]
        =/  mod-for-notify=(unit moderator-profile)  (~(get by moderators.state) moderator-id.updated)
        =/  mod-route-notify=(unit nym-route)  ?~(mod-for-notify ~ (~(get by routes.state) nym-id.u.mod-for-notify))
        =/  direct=(list card)
          ?~(mod-route-notify ~ [(skein-send-card our.bowl u.mod-route-notify notify-msg)]~)
        =/  gpeers=(list @p)
          %+  murn  ~(tap in peers.state)
          |=(p=@p ?:(=(p our.bowl) ~ `p))
        (weld direct (turn gpeers |=(p=@p (gossip-card our.bowl p notify-msg))))
      :-  :(weld [(event-card [%escrow-agreed tid multisig-address.updated])]~ market-cards notify-cards)
      this
    ?:  ?=(%escrow-funded -.msg)
      =/  tid=@uv  thread-id.msg
      =.  escrow-status.state  (~(put by escrow-status.state) tid %funded)
      :-  [(event-card [%escrow-funded tid])]~
      this
    ?:  ?=(%escrow-sign-release -.msg)
      =/  tid=@uv  thread-id.msg
      =/  existing=(map @ud @ux)  (~(gut by escrow-sigs.state) tid ~)
      =.  existing  (~(put by existing) signer-idx.msg sig.msg)
      =.  escrow-sigs.state  (~(put by escrow-sigs.state) tid existing)
      =.  escrow-status.state  (~(put by escrow-status.state) tid %releasing)
      ::  auto-co-sign release: seller always wants the money
      =/  our-priv=(unit @ux)  (~(get by escrow-keys.state) tid)
      =/  esc-for-sign=(unit escrow-config)  (~(get by escrows.state) tid)
      =/  thd-for-role=(unit silk-thread)  (~(get by threads.state) tid)
      =/  we-are-seller=?
        ?~  thd-for-role  %.n
        (~(has by nyms.state) seller.u.thd-for-role)
      =?  existing  ?&(we-are-seller ?=(^ our-priv) ?=(^ esc-for-sign) !=(0 account-number.u.esc-for-sign))
        =/  to-addr=@t  seller-wallet.u.esc-for-sign
        =/  sign-doc=@t
          %:  amino-json-sign-doc-send:multisig
            multisig-address.u.esc-for-sign  to-addr
            amount.u.esc-for-sign  '$sZ'
            200.000  200.000  'zenith-stage1'
            account-number.u.esc-for-sign  sequence.u.esc-for-sign
          ==
        =/  our-sig=@ux  (sign-multisig-part:multisig sign-doc u.our-priv)
        =/  sorted-pks=(list @ux)
          (sort-pubkeys:multisig ~[buyer-pubkey.u.esc-for-sign seller-pubkey.u.esc-for-sign moderator-pubkey.u.esc-for-sign])
        =/  our-pub=@ux  =+(secp256k1:secp:crypto (compress-point (priv-to-pub u.our-priv)))
        =/  our-idx=@ud
          =/  pks  sorted-pks
          =/  idx=@ud  0
          |-
          ?~  pks  0
          ?:  =(i.pks our-pub)  idx
          $(pks t.pks, idx +(idx))
        ~&  [%silk-escrow %auto-co-sign-release tid %idx our-idx]
        (~(put by existing) our-idx our-sig)
      =.  escrow-sigs.state  (~(put by escrow-sigs.state) tid existing)
      ::  auto-assemble when 2 signatures collected
      ?.  (gte ~(wyt by existing) 2)
        :-  [(event-card [%escrow-releasing tid])]~
        this
      =/  esc=(unit escrow-config)  (~(get by escrows.state) tid)
      ?~  esc
        :-  [(event-card [%escrow-releasing tid])]~
        this
      =/  thd=(unit silk-thread)  (~(get by threads.state) tid)
      ?~  thd
        :-  [(event-card [%escrow-releasing tid])]~
        this
      ::  release sends to seller wallet (from escrow-config)
      =/  to-addr=@t  seller-wallet.u.esc
      =/  sorted-pks=(list @ux)
        (sort-pubkeys:multisig ~[buyer-pubkey.u.esc seller-pubkey.u.esc moderator-pubkey.u.esc])
      =/  sig-pairs=(list [@ud @ux])
        %+  sort  ~(tap by existing)
        |=([a=[@ud @ux] b=[@ud @ux]] (lth -.a -.b))
      =/  signer-indices=(list @ud)  (turn sig-pairs |=([i=@ud s=@ux] i))
      =/  signatures=(list @ux)      (turn sig-pairs |=([i=@ud s=@ux] s))
      =/  tx-hex=@t
        %:  assemble-multisig-tx:multisig
          multisig-address.u.esc  to-addr
          amount.u.esc  '$sZ'
          200.000  200.000  'zenith-stage1'
          account-number.u.esc  sequence.u.esc
          sorted-pks  signer-indices  signatures
        ==
      ~&  [%silk-escrow %tx-assembled tid %hex-len (met 3 tx-hex)]
      =.  escrow-txhex.state  (~(put by escrow-txhex.state) tid tx-hex)
      =.  escrow-status.state  (~(put by escrow-status.state) tid %released)
      ::  broadcast assembled tx to zenith chain
      =/  broadcast-card=card
        [%pass /zenith/broadcast %agent [our.bowl %silk-zenith] %poke %noun !>([%broadcast-escrow tid tx-hex])]
      ::  notify all peers of assembled release (so moderator sees 2/2)
      =/  notify-peers=(list @p)
        %+  murn  ~(tap in peers.state)
        |=(p=@p ?:(=(p our.bowl) ~ `p))
      =/  notify-cards=(list card)
        (turn notify-peers |=(p=@p (gossip-card our.bowl p [%escrow-assembled tid %released tx-hex])))
      :-  ;:(weld [(event-card [%escrow-released tid])]~ [broadcast-card]~ notify-cards)
      this
    ?:  ?=(%escrow-sign-refund -.msg)
      =/  tid=@uv  thread-id.msg
      =/  existing=(map @ud @ux)  (~(gut by escrow-sigs.state) tid ~)
      =.  existing  (~(put by existing) signer-idx.msg sig.msg)
      =.  escrow-sigs.state  (~(put by escrow-sigs.state) tid existing)
      =.  escrow-status.state  (~(put by escrow-status.state) tid %refunding)
      ::  auto-co-sign refund: buyer always wants their money back
      ::  seller does NOT auto-co-sign — they must agree manually or dispute
      =/  our-priv=(unit @ux)  (~(get by escrow-keys.state) tid)
      =/  esc-for-sign=(unit escrow-config)  (~(get by escrows.state) tid)
      =/  thd-for-role=(unit silk-thread)  (~(get by threads.state) tid)
      =/  we-are-buyer=?
        ?~  thd-for-role  %.n
        (~(has by nyms.state) buyer.u.thd-for-role)
      =?  existing  ?&(we-are-buyer ?=(^ our-priv) ?=(^ esc-for-sign) !=(0 account-number.u.esc-for-sign))
        =/  to-addr=@t  buyer-wallet.u.esc-for-sign
        =/  sign-doc=@t
          %:  amino-json-sign-doc-send:multisig
            multisig-address.u.esc-for-sign  to-addr
            amount.u.esc-for-sign  '$sZ'
            200.000  200.000  'zenith-stage1'
            account-number.u.esc-for-sign  sequence.u.esc-for-sign
          ==
        =/  our-sig=@ux  (sign-multisig-part:multisig sign-doc u.our-priv)
        =/  sorted-pks=(list @ux)
          (sort-pubkeys:multisig ~[buyer-pubkey.u.esc-for-sign seller-pubkey.u.esc-for-sign moderator-pubkey.u.esc-for-sign])
        =/  our-pub=@ux  =+(secp256k1:secp:crypto (compress-point (priv-to-pub u.our-priv)))
        =/  our-idx=@ud
          =/  pks  sorted-pks
          =/  idx=@ud  0
          |-
          ?~  pks  0
          ?:  =(i.pks our-pub)  idx
          $(pks t.pks, idx +(idx))
        ~&  [%silk-escrow %auto-co-sign-refund tid %idx our-idx]
        (~(put by existing) our-idx our-sig)
      =.  escrow-sigs.state  (~(put by escrow-sigs.state) tid existing)
      ::  auto-assemble when 2 signatures collected
      ?.  (gte ~(wyt by existing) 2)
        :-  [(event-card [%escrow-refunding tid])]~
        this
      =/  esc=(unit escrow-config)  (~(get by escrows.state) tid)
      ?~  esc
        :-  [(event-card [%escrow-refunding tid])]~
        this
      =/  thd=(unit silk-thread)  (~(get by threads.state) tid)
      ?~  thd
        :-  [(event-card [%escrow-refunding tid])]~
        this
      ::  refund sends to buyer wallet (from escrow-config)
      =/  to-addr=@t  buyer-wallet.u.esc
      =/  sorted-pks=(list @ux)
        (sort-pubkeys:multisig ~[buyer-pubkey.u.esc seller-pubkey.u.esc moderator-pubkey.u.esc])
      =/  sig-pairs=(list [@ud @ux])
        %+  sort  ~(tap by existing)
        |=([a=[@ud @ux] b=[@ud @ux]] (lth -.a -.b))
      =/  signer-indices=(list @ud)  (turn sig-pairs |=([i=@ud s=@ux] i))
      =/  signatures=(list @ux)      (turn sig-pairs |=([i=@ud s=@ux] s))
      =/  tx-hex=@t
        %:  assemble-multisig-tx:multisig
          multisig-address.u.esc  to-addr
          amount.u.esc  '$sZ'
          200.000  200.000  'zenith-stage1'
          account-number.u.esc  sequence.u.esc
          sorted-pks  signer-indices  signatures
        ==
      ~&  [%silk-escrow %refund-tx-assembled tid %hex-len (met 3 tx-hex)]
      =.  escrow-txhex.state  (~(put by escrow-txhex.state) tid tx-hex)
      =.  escrow-status.state  (~(put by escrow-status.state) tid %refunded)
      ::  broadcast assembled refund tx to zenith chain
      =/  broadcast-card=card
        [%pass /zenith/broadcast %agent [our.bowl %silk-zenith] %poke %noun !>([%broadcast-escrow tid tx-hex])]
      ::  notify all peers of assembled refund (so moderator sees 2/2)
      =/  notify-peers=(list @p)
        %+  murn  ~(tap in peers.state)
        |=(p=@p ?:(=(p our.bowl) ~ `p))
      =/  notify-cards=(list card)
        (turn notify-peers |=(p=@p (gossip-card our.bowl p [%escrow-assembled tid %refunded tx-hex])))
      :-  ;:(weld [(event-card [%escrow-refunded tid])]~ [broadcast-card]~ notify-cards)
      this
    ::  escrow-assembled: update local state when counterparty assembled tx
    ?:  ?=(%escrow-assembled -.msg)
      =/  tid=@uv  thread-id.msg
      ::  only update if we have this escrow
      ?.  (~(has by escrows.state) tid)  `this
      =.  escrow-status.state  (~(put by escrow-status.state) tid result.msg)
      =.  escrow-txhex.state  (~(put by escrow-txhex.state) tid tx-hex.msg)
      ::  mark sigs as 2 (since assembled = 2 sigs collected)
      =/  fake-sigs=(map @ud @ux)  (~(put by (~(put by *(map @ud @ux)) 0 0x0)) 1 0x0)
      =.  escrow-sigs.state  (~(put by escrow-sigs.state) tid fake-sigs)
      ~&  [%silk-escrow %assembled-received tid result.msg]
      :-  [(event-card [%escrow-assembled tid result.msg])]~
      this
    ::  escrow-notify broadcast — only process if we're the moderator
    ?:  ?=(%escrow-notify -.msg)
      =/  esc=escrow-config  escrow-config.msg
      ::  accept if we hold the moderator's private key (definitive ownership proof)
      =/  has-key=?  (~(has by mod-keys.state) moderator-id.esc)
      ~&  [%silk-escrow %notify-received %mod-id moderator-id.esc %has-key has-key]
      ?.  has-key
        ~&  [%silk-escrow %notify-ignored %no-mod-key moderator-id.esc]
        `this
      =.  escrows.state  (~(put by escrows.state) thread-id.esc esc)
      =.  escrow-status.state  (~(put by escrow-status.state) thread-id.esc %agreed)
      ::  create stub thread so /my-escrows can show buyer/seller
      =/  stub=silk-thread
        [thread-id.esc *listing-id buyer.msg seller.msg %accepted ~ 0x0 now.bowl now.bowl]
      =.  threads.state  (~(put by threads.state) thread-id.esc stub)
      ~&  [%silk-moderator %escrow-assigned thread-id.esc]
      :-  [(event-card [%escrow-agreed thread-id.esc multisig-address.esc])]~
      this
    ::  escrow-dispute broadcast — only process if we're the moderator
    ?:  ?=(%escrow-dispute -.msg)
      =/  tid=@uv  thread-id.msg
      =/  esc=(unit escrow-config)  (~(get by escrows.state) tid)
      ?~  esc  `this  ::  we don't have this escrow — not our concern
      =.  escrow-status.state  (~(put by escrow-status.state) tid %disputed)
      ~&  [%silk-moderator %dispute-received tid]
      :-  [(event-card [%message-received tid msg])]~
      this
    ::  thread sync: respond with full thread if chain differs
    ?:  ?=(%sync-thread -.msg)
      =/  our-thd=(unit silk-thread)  (~(get by threads.state) thread-id.msg)
      ?~  our-thd  `this
      ?.  !=(chain.msg chain.u.our-thd)  `this
      ::  chain mismatch — send our thread state
      =/  sender-nym=nym-id  buyer.u.our-thd
      =/  route=(unit nym-route)  (~(get by routes.state) sender-nym)
      ?~  route  `this
      :_  this
      [(skein-send-card our.bowl u.route [%sync-thread-response u.our-thd])]~
    ::  thread sync response: merge if their chain is longer
    ?:  ?=(%sync-thread-response -.msg)
      =/  remote-thd=silk-thread  +.msg
      =/  our-thd=(unit silk-thread)  (~(get by threads.state) id.remote-thd)
      ?~  our-thd
        ::  we don't have this thread at all, adopt it
        =.  threads.state  (~(put by threads.state) id.remote-thd remote-thd)
        :-  [(event-card [%thread-opened remote-thd])]~
        this
      ::  adopt if they have more messages (simple strategy)
      ?.  (gth (lent messages.remote-thd) (lent messages.u.our-thd))
        `this
      =.  threads.state  (~(put by threads.state) id.remote-thd remote-thd)
      :-  [(event-card [%thread-updated id.remote-thd thread-status.remote-thd])]~
      this
    ::  thread-routed messages
    =/  tid=thread-id
      ?-  -.msg
        %offer           thread-id.msg
        %accept          thread-id.msg
        %reject          thread-id.msg
        %invoice         thread-id.msg
        %payment-proof   thread-id.msg
        %fulfill         thread-id.msg
        %dispute         thread-id.msg
        %verdict         thread-id.msg
        %complete        thread-id.msg
        %direct-message  thread-id.msg
        %ack             thread-id.msg
      ==
    =/  thd=(unit silk-thread)  (~(get by threads.state) tid)
    ?~  thd
      ::  create thread on first contact
      ?:  ?=(%offer -.msg)
        =/  o=offer  +.msg
        =/  init-chain=@ux  (advance-chain `@ux`0 %offer)
        =/  new-thd=silk-thread
          [tid listing-id.o buyer.o seller.o %open [[%offer o] ~] init-chain now.bowl now.bowl]
        =.  threads.state  (~(put by threads.state) tid new-thd)
        ::  send ack back to buyer
        =/  route=(unit nym-route)  (~(get by routes.state) buyer.o)
        =/  ack-cards=(list card)
          ?~  route  ~
          [(skein-send-card our.bowl u.route [%ack tid `@ux`(sham msg) now.bowl])]~
        =/  ev-cards=(list card)
          :~  (event-card [%thread-opened new-thd])
              (event-card [%message-received tid msg])
          ==
        ::  notify silk-market: create order for inbound offer
        =/  mkt-cards=(list card)
          [(market-create-card our.bowl tid listing-id.o buyer.o seller.o id.o amount.o currency.o)]~
        :-  ;:(weld ev-cards ack-cards mkt-cards)
        this
      ?:  ?=(%direct-message -.msg)
        =/  dm-lid=listing-id  listing-id.+.msg
        =/  dm-sender=nym-id  sender.+.msg
        =/  lst=(unit listing)  (~(get by listings.state) dm-lid)
        =/  dm-seller=nym-id
          ?~(lst dm-sender seller.u.lst)
        =/  init-chain=@ux  (advance-chain `@ux`0 %direct-message)
        =/  new-thd=silk-thread
          [tid dm-lid dm-sender dm-seller %open [msg ~] init-chain now.bowl now.bowl]
        =.  threads.state  (~(put by threads.state) tid new-thd)
        :-  :~  (event-card [%thread-opened new-thd])
                (event-card [%message-received tid msg])
            ==
        this
      ::  unknown thread, log and drop
      :-  [(event-card [%message-received tid msg])]~
      this
    ::  acks clear pending resend entries
    ?:  ?=(%ack -.msg)
      =.  pending-acks.state  (~(del by pending-acks.state) msg-hash.msg)
      `this
    ::  update thread status based on inbound message type
    =/  new-status=thread-status
      ?:  ?=(%offer -.msg)
        %open
      ?:  ?=(%accept -.msg)
        %accepted
      ?:  ?=(%reject -.msg)
        %cancelled
      ?:  ?=(%payment-proof -.msg)
        %paid
      ?:  ?=(%fulfill -.msg)
        %fulfilled
      ?:  ?=(%complete -.msg)
        %completed
      ?:  ?=(%dispute -.msg)
        %disputed
      ?:  ?=(%verdict -.msg)
        %resolved
      thread-status.u.thd
    ::  advance chain hash
    =/  new-chain=@ux  (advance-chain chain.u.thd `@tas`-.msg)
    =/  updated=silk-thread
      u.thd(thread-status new-status, messages [msg messages.u.thd], chain new-chain, updated-at now.bowl)
    =.  threads.state  (~(put by threads.state) tid updated)
    ::  auto-sign release when seller receives %complete and escrow is active
    =/  auto-release=(quip card _this)
      ?.  ?=(%complete -.msg)  `this
      =/  esc=(unit escrow-config)  (~(get by escrows.state) tid)
      =/  est=(unit escrow-st)  (~(get by escrow-status.state) tid)
      =/  has-escrow=?
        ?&  ?=(^ esc)
            ?=(^ est)
            ?=(?(%agreed %funded %releasing) u.est)
        ==
      ?.  has-escrow  `this
      ~&  [%silk-escrow %auto-release-on-inbound-complete tid]
      (handle-command [%release-escrow tid])
    =.  this  +.auto-release
    ::  auto-refund when counterparty receives %reject and escrow is active
    =/  auto-refund=(quip card _this)
      ?.  ?=(%reject -.msg)  `this
      =/  esc=(unit escrow-config)  (~(get by escrows.state) tid)
      =/  est=(unit escrow-st)  (~(get by escrow-status.state) tid)
      =/  has-escrow=?
        ?&  ?=(^ esc)
            ?=(^ est)
            ?=(?(%agreed %funded %refunding) u.est)
        ==
      ?.  has-escrow  `this
      ~&  [%silk-escrow %auto-refund-on-inbound-reject tid]
      (handle-command [%refund-escrow tid])
    =.  this  +.auto-refund
    ::  send ack back to message sender
    =/  sender-nym=nym-id
      ?:  ?=(?(%offer %payment-proof %complete) -.msg)
        buyer.u.thd
      ?:  ?=(%direct-message -.msg)
        sender.+.msg
      ?:  ?=(%dispute -.msg)
        plaintiff.+.msg
      seller.u.thd
    =/  route=(unit nym-route)  (~(get by routes.state) sender-nym)
    =/  ack-cards=(list card)
      ?~  route  ~
      [(skein-send-card our.bowl u.route [%ack tid `@ux`(sham msg) now.bowl])]~
    :-  ;:(weld [(event-card [%message-received tid msg])]~ ack-cards -.auto-release -.auto-refund)
    this
  ==
  ::
  ::  http request routing
  ::
  ++  handle-http
    |=  [eyre-id=@ta req=inbound-request:eyre]
    ^-  (quip card _this)
    =/  rl=request-line:server  (parse-request-line:server url.request.req)
    =/  site=(list @t)  site.rl
    ?.  ?=([%apps %silk %api *] site)
      :_  this
      (give-http eyre-id 404 ~[['content-type' 'text/plain']] (some (as-octs:mimes:html 'not found')))
    =/  api-path=(list @t)  t.t.t.site
    ?.  authenticated.req
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      (login-redirect:gen:server request.req)
    ?:  =(%'GET' method.request.req)
      :_  this
      (handle-get eyre-id api-path)
    ?:  =(%'POST' method.request.req)
      (handle-post eyre-id req)
    :_  this
    (give-http eyre-id 405 ~[['content-type' 'text/plain']] (some (as-octs:mimes:html 'method not allowed')))
  ::
  ++  handle-get
    |=  [eyre-id=@ta site=(list @t)]
    ^-  (list card)
    ?+  site
      (give-http eyre-id 404 ~[['content-type' 'text/plain']] (some (as-octs:mimes:html 'not found')))
    ::
        [%nyms ~]
      %-  give-json  :-  eyre-id
      %-  pairs:enjs:format
      :~  ['nyms' [%a (turn ~(val by nyms.state) nym-to-json)]]
      ==
    ::
        [%listings ~]
      %-  give-json  :-  eyre-id
      %-  pairs:enjs:format
      :~  ['listings' [%a (turn ~(val by listings.state) listing-to-json)]]
      ==
    ::
        [%threads ~]
      %-  give-json  :-  eyre-id
      %-  pairs:enjs:format
      :~  ['threads' [%a (turn ~(val by threads.state) thread-to-json)]]
      ==
    ::
        [%peers ~]
      %-  give-json  :-  eyre-id
      %-  pairs:enjs:format
      :~  ['peers' [%a (turn ~(tap in peers.state) |=(s=@p s+(scot %p s)))]]
      ==
    ::
        [%orders ~]
      =/  order-threads=(list silk-thread)
        %+  murn  ~(val by threads.state)
        |=  t=silk-thread
        ?.  ?|  ?=(?(%accepted %paid %fulfilled %completed %disputed %resolved) thread-status.t)
                (~(has by escrows.state) id.t)
            ==
          ~
        `t
      %-  give-json  :-  eyre-id
      %-  pairs:enjs:format
      :~  :-  'orders'
          :-  %a
          %+  turn  order-threads
          |=  t=silk-thread
          =/  offer-data=[amount=@ud cur=@tas]
            =/  msgs=(list silk-message)  messages.t
            |-
            ?~  msgs  [0 %$]
            ?:  ?=(%offer -.i.msgs)  [amount.+.i.msgs currency.+.i.msgs]
            $(msgs t.msgs)
          =/  invoice-info=[has=? pa=@t]
            =/  msgs=(list silk-message)  messages.t
            |-
            ?~  msgs  [| '']
            ?:  ?=(%invoice -.i.msgs)  [& pay-address.+.i.msgs]
            $(msgs t.msgs)
          =/  seller-wallet=@t
            =/  snym=(unit pseudonym)  (~(get by nyms.state) seller.t)
            ?~  snym  ''
            wallet.u.snym
          =/  buyer-wallet=@t
            =/  bnym=(unit pseudonym)  (~(get by nyms.state) buyer.t)
            ?~  bnym  ''
            wallet.u.bnym
          =/  veri=(unit [verified=? balance=@ud checked-at=@da])
            (~(get by verifications.state) id.t)
          ::  compute effective status accounting for escrow state
          =/  esc-st=(unit escrow-st)  (~(get by escrow-status.state) id.t)
          =/  effective-status=@t
            ?:  ?&(?=(^ esc-st) ?=(%proposed u.esc-st) ?=(%accepted thread-status.t))
              'escrow-proposed'
            ?:  ?&(?=(^ esc-st) ?=(%agreed u.esc-st) ?=(%accepted thread-status.t) has.invoice-info)
              'accepted'
            ?:  ?&(?=(^ esc-st) ?=(%agreed u.esc-st) ?=(%accepted thread-status.t))
              'escrow-agreed'
            ?:  ?&(?=(^ esc-st) ?=(?(%agreed %funded) u.esc-st) ?=(%paid thread-status.t))
              'escrowed'
            `@t`thread-status.t
          %-  pairs:enjs:format
          :~  ['thread_id' s+(scot %uv id.t)]
              ['listing_id' s+(scot %uv listing-id.t)]
              ['buyer' s+(scot %uv buyer.t)]
              ['seller' s+(scot %uv seller.t)]
              ['status' s+effective-status]
              ['amount' (numb:enjs:format amount.offer-data)]
              ['currency' s+`@t`cur.offer-data]
              ['has_invoice' b+has.invoice-info]
              ['pay_address' s+pa.invoice-info]
              ['seller_wallet' s+seller-wallet]
              ['buyer_wallet' s+buyer-wallet]
              :-  'verification'
              ?~  veri  ~
              %-  pairs:enjs:format
              :~  ['verified' b+verified.u.veri]
                  ['balance' (numb:enjs:format balance.u.veri)]
                  ['checked_at' (numb:enjs:format (div (sub checked-at.u.veri ~1970.1.1) ~s1))]
              ==
              ['messages' [%a (turn (flop messages.t) message-to-json)]]
              ['updated_at' (numb:enjs:format (div (sub updated-at.t ~1970.1.1) ~s1))]
              :-  'escrow'
              =/  esc=(unit escrow-config)  (~(get by escrows.state) id.t)
              =/  est=(unit escrow-st)  (~(get by escrow-status.state) id.t)
              ?~  esc  ~
              =/  sigs=(map @ud @ux)  (~(gut by escrow-sigs.state) id.t ~)
              %-  pairs:enjs:format
              :~  ['status' s+?~(est 'unknown' `@t`u.est)]
                  ['multisig_address' s+multisig-address.u.esc]
                  ['moderator_id' s+(scot %uv moderator-id.u.esc)]
                  ['amount' (numb:enjs:format amount.u.esc)]
                  ['currency' s+`@t`currency.u.esc]
                  ['moderator_fee_bps' (numb:enjs:format moderator-fee-bps.u.esc)]
                  ['sigs_collected' (numb:enjs:format ~(wyt by sigs))]
                  ['tx_hex' s+(~(gut by escrow-txhex.state) id.t '')]
              ==
          ==
      ==
    ::
        [%reputation ~]
      =/  atts=(list attestation)  ~(val by attestations.state)
      =/  score-map=(map nym-id [total=@ud count=@ud])
        =/  ats=(list attestation)  atts
        =/  acc=(map nym-id [total=@ud count=@ud])  ~
        |-
        ?~  ats  acc
        =/  cur  (~(get by acc) subject.i.ats)
        =/  prev=[total=@ud count=@ud]  ?~(cur [0 0] u.cur)
        $(ats t.ats, acc (~(put by acc) subject.i.ats [(add total.prev score.i.ats) +(count.prev)]))
      %-  give-json  :-  eyre-id
      %-  pairs:enjs:format
      :~  :-  'scores'
          :-  %a
          %+  turn  ~(tap by score-map)
          |=  [nid=nym-id total=@ud count=@ud]
          %-  pairs:enjs:format
          :~  ['nym_id' s+(scot %uv nid)]
              ['score' (numb:enjs:format ?:(=(0 count) 0 (div total count)))]
              ['count' (numb:enjs:format count)]
          ==
        ::
          :-  'attestations'
          :-  %a
          %+  turn  atts
          |=  a=attestation
          %-  pairs:enjs:format
          :~  ['id' s+(scot %uv id.a)]
              ['subject' s+(scot %uv subject.a)]
              ['issuer' s+(scot %uv issuer.a)]
              ['kind' s+`@t`kind.a]
              ['score' (numb:enjs:format score.a)]
              ['note' s+note.a]
              ['issued_at' (numb:enjs:format (div (sub issued-at.a ~1970.1.1) ~s1))]
          ==
      ==
    ::
        [%moderators ~]
      %-  give-json  :-  eyre-id
      %-  pairs:enjs:format
      :~  :-  'moderators'
          :-  %a
          %+  turn  ~(val by moderators.state)
          |=  mp=moderator-profile
          %-  pairs:enjs:format
          :~  ['id' s+(scot %uv id.mp)]
              ['nym_id' s+(scot %uv nym-id.mp)]
              ['pubkey' s+(scot %ux pubkey.mp)]
              ['address' s+address.mp]
              ['fee_bps' (numb:enjs:format fee-bps.mp)]
              ['stake_amount' (numb:enjs:format stake-amount.mp)]
              ['description' s+description.mp]
              ['created_at' (numb:enjs:format (div (sub created-at.mp ~1970.1.1) ~s1))]
          ==
      ==
    ::
        [%escrow @ ~]
      =/  tid=@uv  (slav %uv i.t.site)
      =/  esc=(unit escrow-config)  (~(get by escrows.state) tid)
      =/  est=(unit escrow-st)  (~(get by escrow-status.state) tid)
      =/  sigs=(map @ud @ux)  (~(gut by escrow-sigs.state) tid ~)
      %-  give-json  :-  eyre-id
      %-  pairs:enjs:format
      :~  ['thread_id' s+(scot %uv tid)]
          :-  'config'
          ?~  esc  ~
          %-  pairs:enjs:format
          :~  ['buyer_pubkey' s+(scot %ux buyer-pubkey.u.esc)]
              ['seller_pubkey' s+(scot %ux seller-pubkey.u.esc)]
              ['moderator_pubkey' s+(scot %ux moderator-pubkey.u.esc)]
              ['moderator_id' s+(scot %uv moderator-id.u.esc)]
              ['multisig_address' s+multisig-address.u.esc]
              ['amount' (numb:enjs:format amount.u.esc)]
              ['currency' s+`@t`currency.u.esc]
              ['moderator_fee_bps' (numb:enjs:format moderator-fee-bps.u.esc)]
          ==
          ['status' ?~(est ~ s+`@t`u.est)]
          ['sigs_collected' (numb:enjs:format ~(wyt by sigs))]
          ['tx_hex' s+(~(gut by escrow-txhex.state) tid '')]
      ==
    ::
        [%'my-escrows' ~]
      ::  return escrows where we hold the moderator's private key
      ~&  [%my-escrows-debug %escrows ~(wyt by escrows.state) %mods ~(wyt by moderators.state) %mod-keys ~(wyt by mod-keys.state)]
      =/  results=(list json)
        %+  murn  ~(tap by escrows.state)
        |=  [tid=@uv esc=escrow-config]
        =/  has-key=?  (~(has by mod-keys.state) moderator-id.esc)
        ~&  [%my-escrows-check tid %mod-id moderator-id.esc %has-key has-key]
        ?.  has-key  ~
        =/  est=(unit escrow-st)  (~(get by escrow-status.state) tid)
        =/  sigs=(map @ud @ux)  (~(gut by escrow-sigs.state) tid ~)
        =/  thd=(unit silk-thread)  (~(get by threads.state) tid)
        :-  ~
        %-  pairs:enjs:format
        :~  ['thread_id' s+(scot %uv tid)]
            ['multisig_address' s+multisig-address.esc]
            ['amount' (numb:enjs:format amount.esc)]
            ['currency' s+`@t`currency.esc]
            ['status' ?~(est ~ s+`@t`u.est)]
            ['sigs_collected' (numb:enjs:format ~(wyt by sigs))]
            ['tx_hex' s+(~(gut by escrow-txhex.state) tid '')]
            ['buyer' ?~(thd ~ s+(scot %uv buyer.u.thd))]
            ['seller' ?~(thd ~ s+(scot %uv seller.u.thd))]
            ['moderator_id' s+(scot %uv moderator-id.esc)]
        ==
      %-  give-json  :-  eyre-id
      %-  pairs:enjs:format
      :~  ['escrows' [%a results]]
      ==
    ::
        [%'escrow-debug' ~]
      ::  dump all escrow state for debugging
      =/  entries=(list json)
        %+  turn  ~(tap by escrows.state)
        |=  [tid=@uv esc=escrow-config]
        =/  est=(unit escrow-st)  (~(get by escrow-status.state) tid)
        =/  sigs=(map @ud @ux)  (~(gut by escrow-sigs.state) tid ~)
        =/  has-key=?  (~(has by escrow-keys.state) tid)
        =/  txhex=@t  (~(gut by escrow-txhex.state) tid '')
        %-  pairs:enjs:format
        :~  ['thread_id' s+(scot %uv tid)]
            ['escrow_status' ?~(est ~ s+`@t`u.est)]
            ['sigs_count' (numb:enjs:format ~(wyt by sigs))]
            ['has_escrow_key' b+has-key]
            ['multisig_address' s+multisig-address.esc]
            ['moderator_id' s+(scot %uv moderator-id.esc)]
            ['buyer_pubkey' s+(scot %ux buyer-pubkey.esc)]
            ['seller_pubkey' s+(scot %ux seller-pubkey.esc)]
            ['mod_pubkey' s+(scot %ux moderator-pubkey.esc)]
            ['buyer_wallet' s+buyer-wallet.esc]
            ['seller_wallet' s+seller-wallet.esc]
            ['amount' (numb:enjs:format amount.esc)]
            ['has_tx_hex' b+!=('' txhex)]
            :-  'sig_indices'
            [%a (turn ~(tap by sigs) |=([idx=@ud sig=@ux] (numb:enjs:format idx)))]
        ==
      %-  give-json  :-  eyre-id
      %-  pairs:enjs:format
      :~  ['escrows' [%a entries]]
          ['escrow_count' (numb:enjs:format ~(wyt by escrows.state))]
          ['escrow_status_count' (numb:enjs:format ~(wyt by escrow-status.state))]
          ['escrow_keys_count' (numb:enjs:format ~(wyt by escrow-keys.state))]
          ['escrow_sigs_count' (numb:enjs:format ~(wyt by escrow-sigs.state))]
          ['mod_keys_count' (numb:enjs:format ~(wyt by mod-keys.state))]
          ['moderators_count' (numb:enjs:format ~(wyt by moderators.state))]
      ==
    ::
        [%'zenith-accounts' ~]
      ::  scry zenith for available wallet accounts
      ::  returns account names + addresses from zenith agent
      =/  result
        (mule |.(.^(* %gx /(scot %p our.bowl)/zenith/(scot %da now.bowl)/accounts/noun)))
      ?:  ?=(%| -.result)
        %-  give-json  :-  eyre-id
        (pairs:enjs:format ~[['accounts' [%a ~]]])
      ::  p.result is (map acc-name account) where account = [addr pub priv acc-num seq-num]
      ::  extract names and addresses
      =/  entries=(list [@t *])  ~(tap by ;;((map @t *) p.result))
      %-  give-json  :-  eyre-id
      %-  pairs:enjs:format
      :~  :-  'accounts'
          :-  %a
          %+  turn  entries
          |=  [name=@t val=*]
          =/  addr=@t  ;;(@t -.val)
          (pairs:enjs:format ~[['name' s+name] ['address' s+addr]])
      ==
    ::
        [%stats ~]
      %-  give-json  :-  eyre-id
      %-  pairs:enjs:format
      :~  ['nyms' (numb:enjs:format ~(wyt by nyms.state))]
          ['listings' (numb:enjs:format ~(wyt by listings.state))]
          ['threads' (numb:enjs:format ~(wyt by threads.state))]
          ['routes' (numb:enjs:format ~(wyt by routes.state))]
          ['peers' (numb:enjs:format ~(wyt in peers.state))]
          ['pendingAcks' (numb:enjs:format ~(wyt by pending-acks.state))]
          ['keys' (numb:enjs:format ~(wyt by keys.state))]
          ['moderators' (numb:enjs:format ~(wyt by moderators.state))]
          ['escrows' (numb:enjs:format ~(wyt by escrows.state))]
          ['ship' s+(scot %p our.bowl)]
      ==
    ==
  ::
  ++  handle-post
    |=  [eyre-id=@ta req=inbound-request:eyre]
    ^-  (quip card _this)
    =/  body=@t
      ?~  body.request.req  ''
      `@t`q.u.body.request.req
    =/  jon=(unit json)  (de:json:html body)
    ?~  jon
      :_  this
      (give-http eyre-id 400 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"bad json"}')))
    ::  extract action type for routing
    =/  typ=(unit @t)
      =/  res  (mule |.(((ot:dejs:format ~[action+so:dejs:format]) u.jon)))
      ?:(?=(%& -.res) `p.res ~)
    ?~  typ
      :_  this
      (give-http eyre-id 400 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"bad action"}')))
    ::  inventory-aware actions
    ?:  =(%'post-listing' u.typ)
      =,  dejs:format
      =/  f  (ot ~[title+so description+so price+ni currency+so nym+so inventory+ni])
      =/  [title=@t description=@t price=@ud currency=@t nym=@t inv=@ud]  (f u.jon)
      =/  id=listing-id  (sham [our.bowl now.bowl title])
      =/  seller=nym-id  (slav %uv nym)
      =/  lst=listing  [id seller title description price `@tas`currency now.bowl ~]
      =/  result  (handle-command [%post-listing lst])
      =.  inventory.state  ?:(=(inv 0) inventory.state (~(put by inventory.state) id inv))
      :_  +.result
      %+  weld  -.result
      (give-http eyre-id 200 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"ok":true}')))
    ?:  =(%'update-inventory' u.typ)
      =,  dejs:format
      =/  f  (ot ~[id+so inventory+ni])
      =/  [id-t=@t inv=@ud]  (f u.jon)
      =/  lid=listing-id  (slav %uv id-t)
      ?~  (~(get by listings.state) lid)
        :_(this (give-http eyre-id 404 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"listing not found"}'))))
      =.  inventory.state
        ?:(=(inv 0) (~(del by inventory.state) lid) (~(put by inventory.state) lid inv))
      :_  this
      (give-http eyre-id 200 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"ok":true}')))
    ::  payment-flow actions (need state access to derive full types)
    ?:  =(%'send-invoice' u.typ)
      (handle-api-invoice eyre-id u.jon)
    ?:  =(%'submit-payment' u.typ)
      (handle-api-payment eyre-id u.jon)
    ?:  =(%'mark-fulfilled' u.typ)
      (handle-api-fulfill eyre-id u.jon)
    ?:  =(%'confirm-complete' u.typ)
      (handle-api-complete eyre-id u.jon)
    ?:  =(%'leave-feedback' u.typ)
      (handle-api-feedback eyre-id u.jon)
    ?:  =(%'send-message' u.typ)
      (handle-api-message eyre-id u.jon)
    ?:  =(%'send-reply' u.typ)
      (handle-api-reply eyre-id u.jon)
    ?:  =(%'verify-payment' u.typ)
      (handle-api-verify eyre-id u.jon)
    ?:  =(%'register-moderator' u.typ)
      (handle-api-register-moderator eyre-id u.jon)
    ?:  =(%'propose-escrow' u.typ)
      (handle-api-propose-escrow eyre-id u.jon)
    ?:  =(%'agree-escrow' u.typ)
      (handle-api-agree-escrow eyre-id u.jon)
    ?:  =(%'fund-escrow' u.typ)
      (handle-api-fund-escrow eyre-id u.jon)
    ?:  =(%'release-escrow' u.typ)
      (handle-api-release-escrow eyre-id u.jon)
    ?:  =(%'refund-escrow' u.typ)
      (handle-api-refund-escrow eyre-id u.jon)
    ?:  =(%'sign-escrow' u.typ)
      (handle-api-sign-escrow eyre-id u.jon)
    ?:  =(%'file-dispute' u.typ)
      (handle-api-file-dispute eyre-id u.jon)
    ?:  =(%'pay-invoice' u.typ)
      (handle-api-pay-invoice eyre-id u.jon)
    ?:  =(%'rebroadcast-escrow' u.typ)
      =,  dejs:format
      =/  tid-t=@t  ((ot ~['thread_id'^so]) u.jon)
      =/  tid=@uv  (slav %uv tid-t)
      =/  tx-hex=@t  (~(gut by escrow-txhex.state) tid '')
      ?:  =('' tx-hex)
        :_(this (err-response eyre-id 'no assembled tx for this escrow'))
      =/  result  (handle-command [%rebroadcast-escrow tid])
      :_  +.result
      %+  weld  -.result
      (ok-response eyre-id)
    ::  existing command flow
    =/  cmd=(unit silk-command)  (parse-action u.jon)
    ?~  cmd
      :_  this
      (give-http eyre-id 400 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"bad action"}')))
    =/  result  (handle-command u.cmd)
    :_  +.result
    %+  weld  -.result
    (give-http eyre-id 200 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"ok":true}')))
  ::
  ::  json action parsing
  ::
  ++  parse-action
    |=  jon=json
    ^-  (unit silk-command)
    =/  res  (mule |.((parse-action-raw jon)))
    ?:  ?=(%& -.res)  `p.res
    ~
  ::
  ++  parse-action-raw
    |=  jon=json
    ^-  silk-command
    =,  dejs:format
    =/  typ=@t  ((ot ~[action+so]) jon)
    ?+  typ  !!
        %'create-nym'
      =/  [label=@t wallet=@t]  ((ot ~[label+so wallet+so]) jon)
      [%create-nym label wallet]
    ::
        %'drop-nym'
      =/  id=@t  ((ot ~[id+so]) jon)
      [%drop-nym (slav %uv id)]
    ::
        %'retract-listing'
      =/  id=@t  ((ot ~[id+so]) jon)
      [%retract-listing (slav %uv id)]
    ::
        %'add-peer'
      =/  ship=@t  ((ot ~[ship+so]) jon)
      [%add-peer (slav %p ship)]
    ::
        %'drop-peer'
      =/  ship=@t  ((ot ~[ship+so]) jon)
      [%drop-peer (slav %p ship)]
    ::
        %'sync-catalog'
      [%sync-catalog ~]
    ::
        %'send-offer'
      =/  f  (ot ~['listing_id'^so seller+so amount+ni currency+so nym+so])
      =/  [lid=@t seller-t=@t amount=@ud currency=@t nym=@t]  (f jon)
      =/  lid-uv=@uv  (slav %uv lid)
      =/  seller-uv=nym-id  (slav %uv seller-t)
      =/  buyer-uv=nym-id  (slav %uv nym)
      =/  oid=offer-id  (sham [our.bowl now.bowl eny.bowl lid-uv])
      =/  tid=thread-id  (sham [our.bowl now.bowl eny.bowl lid-uv buyer-uv])
      =/  off=offer  [oid tid lid-uv buyer-uv seller-uv amount `@tas`currency '' now.bowl]
      [%send-offer off]
    ::
        %'accept-offer'
      =/  f  (ot ~['thread_id'^so 'offer_id'^so])
      =/  [tid=@t oid=@t]  (f jon)
      [%accept-offer (slav %uv tid) (slav %uv oid)]
    ::
        %'reject-offer'
      =/  f  (ot ~['thread_id'^so 'offer_id'^so reason+so])
      =/  [tid=@t oid=@t reason=@t]  (f jon)
      [%reject-offer (slav %uv tid) (slav %uv oid) reason]
    ::
        %'cancel-thread'
      =/  f  (ot ~['thread_id'^so reason+so])
      =/  [tid=@t reason=@t]  (f jon)
      [%cancel-thread (slav %uv tid) reason]
    ::
        %'retract-moderator'
      =/  id=@t  ((ot ~[id+so]) jon)
      [%retract-moderator (slav %uv id)]
    ==
  ::
  ::  payment-flow API handlers (derive full types from state)
  ::
  ++  ok-response
    |=  eyre-id=@ta
    ^-  (list card)
    (give-http eyre-id 200 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"ok":true}')))
  ::
  ++  err-response
    |=  [eyre-id=@ta msg=@t]
    ^-  (list card)
    =/  body=@t  (rap 3 '{"error":"' msg '"}' ~)
    (give-http eyre-id 400 ~[['content-type' 'application/json']] (some (as-octs:mimes:html body)))
  ::
  ++  handle-api-invoice
    |=  [eyre-id=@ta jon=json]
    ^-  (quip card _this)
    =/  tid-t=@t
      =,  dejs:format
      ((ot ~['thread_id'^so]) jon)
    =/  tid=@uv  (slav %uv tid-t)
    =/  thd=(unit silk-thread)  (~(get by threads.state) tid)
    ?~  thd
      :_(this (err-response eyre-id 'thread not found'))
    =/  off=(unit offer)  (find-offer messages.u.thd)
    ?~  off
      :_(this (err-response eyre-id 'no offer in thread'))
    ::  check if escrow is active — if so, invoice points to multisig
    =/  esc=(unit escrow-config)  (~(get by escrows.state) tid)
    =/  est=(unit escrow-st)  (~(get by escrow-status.state) tid)
    ?:  ?&  ?=(^ esc)
            ?=(^ est)
            ?=(?(%agreed %funded %releasing %refunding %disputed) u.est)
            !=('' multisig-address.u.esc)
        ==
      ::  use multisig address directly — no zenith rotation needed
      =/  inv=invoice
        :*  (sham [our.bowl now.bowl tid])
            tid
            id.u.off
            seller.u.thd
            amount.u.off
            currency.u.off
            multisig-address.u.esc
            (add now.bowl ~d7)
        ==
      =/  result  (handle-command [%send-invoice inv])
      :_  +.result
      %+  weld  -.result
      (ok-response eyre-id)
    ::  no escrow: generate fresh private key for this transaction
    =/  priv-key=@ux  `@ux`(shax (jam [tid now.bowl eny.bowl]))
    =/  acc-name=@t  (scot %uv tid)
    ~&  [%silk-invoice %generating-address tid acc-name]
    ::  poke zenith to register the key — on poke-ack we scry the address
    =/  zen-card=card
      [%pass /zenith-addr/(scot %uv tid) %agent [our.bowl %zenith] %poke %add-account !>([acc-name priv-key])]
    :_  this
    (weld [zen-card]~ (ok-response eyre-id))
  ::
  ++  handle-api-payment
    |=  [eyre-id=@ta jon=json]
    ^-  (quip card _this)
    =/  [tid-t=@t txh-t=@t]
      =,  dejs:format
      ((ot ~['thread_id'^so 'tx_hash'^so]) jon)
    =/  tid=@uv  (slav %uv tid-t)
    =/  thd=(unit silk-thread)  (~(get by threads.state) tid)
    ?~  thd
      :_(this (err-response eyre-id 'thread not found'))
    ::  validate: thread must have an invoice
    =/  inv=(unit invoice)  (find-invoice messages.u.thd)
    ?~  inv
      :_(this (err-response eyre-id 'no invoice in thread - seller must invoice first'))
    ::  validate: tx hash must not be empty
    ?:  =('' txh-t)
      :_(this (err-response eyre-id 'tx_hash is required'))
    =/  pp=payment-proof
      :*  tid
          id.u.inv
          txh-t
          now.bowl
      ==
    =/  result  (handle-command [%submit-payment pp])
    :_  +.result
    %+  weld  -.result
    (ok-response eyre-id)
  ::
  ++  handle-api-fulfill
    |=  [eyre-id=@ta jon=json]
    ^-  (quip card _this)
    =/  [tid-t=@t ful-note=@t]
      =,  dejs:format
      ((ot ~['thread_id'^so note+so]) jon)
    =/  tid=@uv  (slav %uv tid-t)
    =/  thd=(unit silk-thread)  (~(get by threads.state) tid)
    ?~  thd
      :_(this (err-response eyre-id 'thread not found'))
    =/  off=(unit offer)  (find-offer messages.u.thd)
    =/  oid=offer-id  ?~(off (sham tid) id.u.off)
    =/  ful=fulfillment
      :*  tid
          oid
          ful-note
          ~
          now.bowl
      ==
    =/  result  (handle-command [%send-fulfillment ful])
    :_  +.result
    %+  weld  -.result
    (ok-response eyre-id)
  ::
  ++  handle-api-complete
    |=  [eyre-id=@ta jon=json]
    ^-  (quip card _this)
    =/  tid-t=@t
      =,  dejs:format
      ((ot ~['thread_id'^so]) jon)
    =/  tid=@uv  (slav %uv tid-t)
    =/  thd=(unit silk-thread)  (~(get by threads.state) tid)
    ?~  thd
      :_(this (err-response eyre-id 'thread not found'))
    =/  complete-msg=silk-message  [%complete tid now.bowl]
    =/  nc=@ux  (advance-chain chain.u.thd %complete)
    =/  updated=silk-thread
      u.thd(thread-status %completed, messages [complete-msg messages.u.thd], chain nc, updated-at now.bowl)
    =.  threads.state  (~(put by threads.state) tid updated)
    ::  send completion to counterparty over skein
    =/  counter=nym-id  seller.u.thd
    =/  route=(unit nym-route)  (~(get by routes.state) counter)
    =/  send-cards=(list card)
      ?~  route
        ~&  [%silk-warn %no-route-for-complete counter]
        ~
      [(skein-send-card our.bowl u.route complete-msg)]~
    =/  mkt-cards=(list card)
      [(market-advance-card our.bowl tid %completed)]~
    ::  auto-sign release if escrow is active
    =/  esc=(unit escrow-config)  (~(get by escrows.state) tid)
    =/  est=(unit escrow-st)  (~(get by escrow-status.state) tid)
    ~&  [%silk-escrow %complete-escrow-check tid %has-esc ?=(^ esc) %has-est ?=(^ est) %est-val ?~(est ~ `u.est) %has-key ?=(^ (~(get by escrow-keys.state) tid))]
    =/  has-escrow=?
      ?&  ?=(^ esc)
          ?=(^ est)
          ?=(?(%agreed %funded %releasing) u.est)
      ==
    =/  release-result=(quip card _this)
      ?.  has-escrow  `this
      ~&  [%silk-escrow %auto-release-on-complete tid]
      (handle-command [%release-escrow tid])
    :_  +.release-result
    ;:  weld
      [(event-card [%thread-updated tid %completed])]~
      send-cards
      mkt-cards
      -.release-result
      (ok-response eyre-id)
    ==
  ::
  ++  handle-api-feedback
    |=  [eyre-id=@ta jon=json]
    ^-  (quip card _this)
    =/  parsed=[tid-t=@t sc=@ud nt=@t nym-t=@t]
      =,  dejs:format
      ((ot ~['thread_id'^so score+ni note+so nym+so]) jon)
    =/  tid=@uv  (slav %uv tid-t.parsed)
    =/  thd=(unit silk-thread)  (~(get by threads.state) tid)
    ?~  thd
      :_(this (err-response eyre-id 'thread not found'))
    =/  issuer=nym-id  (slav %uv nym-t.parsed)
    =/  subject=nym-id
      ?:  =(issuer buyer.u.thd)
        seller.u.thd
      buyer.u.thd
    =/  att-id=attest-id  (sham [our.bowl now.bowl tid issuer])
    =/  unsigned=attestation
      [att-id subject issuer %completion sc.parsed nt.parsed now.bowl `@ux`0]
    ::  sign with issuer's key if available
    =/  kp=(unit nym-keypair)  (~(get by keys.state) issuer)
    =/  att=attestation
      ?~  kp  unsigned
      =/  msg=@  (jam [id.unsigned subject.unsigned issuer.unsigned kind.unsigned score.unsigned note.unsigned issued-at.unsigned])
      unsigned(sig (sign:ed:crypto msg sec.u.kp))
    =.  attestations.state  (~(put by attestations.state) id.att att)
    =/  route=(unit nym-route)  (~(get by routes.state) subject)
    =/  send-cards=(list card)
      ?~  route  ~
      [(skein-send-card our.bowl u.route [%attest att])]~
    =/  all-cards=(list card)
      :*  [%pass /silk/rep %agent [our.bowl %silk-rep] %poke %noun !>([%issue att])]
          (weld send-cards (ok-response eyre-id))
      ==
    :_(this all-cards)
  ::
  ++  handle-api-message
    |=  [eyre-id=@ta jon=json]
    ^-  (quip card _this)
    =/  parsed=[lid-t=@t nym-t=@t text=@t]
      =,  dejs:format
      ((ot ~['listing_id'^so nym+so text+so]) jon)
    =/  lid-t=@t  lid-t.parsed
    =/  nym-t=@t  nym-t.parsed
    =/  text=@t  text.parsed
    =/  lid=@uv  (slav %uv lid-t)
    =/  sender=nym-id  (slav %uv nym-t)
    =/  lst=(unit listing)  (~(get by listings.state) lid)
    ?~  lst
      :_(this (err-response eyre-id 'listing not found'))
    =/  tid=thread-id  (sham [lid sender seller.u.lst %dm now.bowl])
    =/  dm=silk-message  [%direct-message tid lid sender text now.bowl]
    =/  init-chain=@ux  (advance-chain `@ux`0 %direct-message)
    =/  new-thd=silk-thread
      [tid lid sender seller.u.lst %open [dm ~] init-chain now.bowl now.bowl]
    =.  threads.state  (~(put by threads.state) tid new-thd)
    =/  sender-route=nym-route  [sender our.bowl %silk-core]
    =.  routes.state  (~(put by routes.state) sender sender-route)
    =/  route=(unit nym-route)  (~(get by routes.state) seller.u.lst)
    =/  send-cards=(list card)
      ?~  route
        ~&  [%silk-warn %no-route-for-dm seller.u.lst]
        ~
      :~  (skein-send-card our.bowl u.route dm)
          (skein-send-card our.bowl u.route [%catalog ~ [sender-route]~])
      ==
    :_  this
    %+  weld  [(event-card [%thread-opened new-thd])]~
    %+  weld  send-cards
    (ok-response eyre-id)
  ::
  ++  handle-api-reply
    |=  [eyre-id=@ta jon=json]
    ^-  (quip card _this)
    =/  parsed=[tid-t=@t nym-t=@t text=@t]
      =,  dejs:format
      ((ot ~['thread_id'^so nym+so text+so]) jon)
    =/  tid-t=@t  tid-t.parsed
    =/  nym-t=@t  nym-t.parsed
    =/  text=@t  text.parsed
    =/  tid=@uv  (slav %uv tid-t)
    =/  sender=nym-id  (slav %uv nym-t)
    =/  thd=(unit silk-thread)  (~(get by threads.state) tid)
    ?~  thd
      :_(this (err-response eyre-id 'thread not found'))
    =/  dm=silk-message
      [%direct-message tid listing-id.u.thd sender text now.bowl]
    =/  nc=@ux  (advance-chain chain.u.thd %direct-message)
    =/  updated=silk-thread
      u.thd(messages [dm messages.u.thd], chain nc, updated-at now.bowl)
    =.  threads.state  (~(put by threads.state) tid updated)
    =/  counter=nym-id
      ?:  =(sender buyer.u.thd)
        seller.u.thd
      buyer.u.thd
    =/  route=(unit nym-route)  (~(get by routes.state) counter)
    =/  send-cards=(list card)
      ?~  route  ~
      [(skein-send-card our.bowl u.route dm)]~
    :_  this
    %+  weld  [(event-card [%message-received tid dm])]~
    %+  weld  send-cards
    (ok-response eyre-id)
  ::
  ++  handle-api-pay-invoice
    |=  [eyre-id=@ta jon=json]
    ^-  (quip card _this)
    =/  [tid-t=@t acc-name=@t]
      =,  dejs:format
      ((ot ~['thread_id'^so 'account'^so]) jon)
    =/  tid=@uv  (slav %uv tid-t)
    =/  thd=(unit silk-thread)  (~(get by threads.state) tid)
    ?~  thd
      :_(this (err-response eyre-id 'thread not found'))
    ::  find invoice in thread
    =/  inv=(unit invoice)  (find-invoice messages.u.thd)
    ?~  inv
      :_(this (err-response eyre-id 'no invoice in thread'))
    =/  pay-addr=@t  pay-address.u.inv
    ?:  =('' pay-addr)
      :_(this (err-response eyre-id 'invoice has no payment address yet'))
    =/  amount=@ud  amount.u.inv
    ::  normalize denom: chain expects '$sZ', listings may store 'sZ'
    =/  denom=@t
      =/  raw=@t  currency.u.inv
      ?:  |(=('$sZ' raw) =('$sz' raw))  raw
      ?:  |(=('sZ' raw) =('sz' raw))  '$sZ'
      raw
    ~&  [%silk-pay %sending tid %from acc-name %to pay-addr %amount amount %denom denom]
    ::  poke %zenith agent to send payment (zenith runs the thread internally)
    =/  send-card=card
      [%pass /zenith-pay/(scot %uv tid) %agent [our.bowl %zenith] %poke %send-to-addr !>([acc-name pay-addr amount denom])]
    ::  set balance poll timer (10s from now) to verify payment landed
    =/  poll-card=card
      [%pass /zenith-poll/(scot %uv tid) %arvo %b %wait (add now.bowl ~s10)]
    :_  this
    ;:(weld ~[send-card poll-card] (ok-response eyre-id))
  ::
  ++  handle-api-verify
    |=  [eyre-id=@ta jon=json]
    ^-  (quip card _this)
    =/  tid-t=@t
      =,  dejs:format
      ((ot ~['thread_id'^so]) jon)
    =/  tid=@uv  (slav %uv tid-t)
    =/  thd=(unit silk-thread)  (~(get by threads.state) tid)
    ?~  thd
      :_(this (err-response eyre-id 'thread not found'))
    ::  get pay address from the invoice in this thread
    =/  inv=(unit invoice)  (find-invoice messages.u.thd)
    ?~  inv
      :_(this (err-response eyre-id 'no invoice in thread'))
    =/  pay-addr=@t  pay-address.u.inv
    ?:  =('' pay-addr)
      :_(this (err-response eyre-id 'invoice has no payment address'))
    =/  inv-amount=@ud  amount.u.inv
    ::  look up existing verification
    =/  ver=(unit [verified=? balance=@ud checked-at=@da])
      (~(get by verifications.state) tid)
    ::  fire balance check for the per-tx payment address
    ~&  [%silk-verify %checking-address pay-addr %amount inv-amount]
    =/  khan-cards=(list card)
      :~  [%pass /zenith-check/(scot %uv tid) %arvo %k %fard %zenith %get-balances-by-addr %noun !>(pay-addr)]
      ==
    ::  return current state immediately
    =/  resp=json
      %-  pairs:enjs:format
      :~  ['thread_id' s+(scot %uv tid)]
          ['pay_address' s+pay-addr]
          ['invoice_amount' (numb:enjs:format inv-amount)]
          ['status' s+`@t`thread-status.u.thd]
          ['verified' ?~(ver ~ b+verified.u.ver)]
          ['balance' ?~(ver ~ (numb:enjs:format balance.u.ver))]
          ['checked_at' ?~(ver ~ (numb:enjs:format (div (sub checked-at.u.ver ~1970.1.1) ~s1)))]
      ==
    :_  this
    (weld khan-cards (give-json eyre-id resp))
  ::
  ++  handle-api-register-moderator
    |=  [eyre-id=@ta jon=json]
    ^-  (quip card _this)
    =,  dejs:format
    =/  f  (ot ~['nym_id'^so description+so 'fee_bps'^ni 'stake_amount'^ni])
    =/  [nym-t=@t desc=@t fbps=@ud stake=@ud]  (f jon)
    =/  nid=nym-id  (slav %uv nym-t)
    =/  mid=moderator-id  (sham [our.bowl now.bowl eny.bowl %moderator nid])
    ::  generate secp256k1 key for moderator stake
    =/  seed  (jam [our.bowl now.bowl eny.bowl mid %mod-key])
    =/  priv=@ux  `@ux`(shax seed)
    =/  pub=@ux  =+(secp256k1:secp:crypto (compress-point (priv-to-pub priv)))
    ::  sign moderator-id with the key to prove control
    =/  sig=@ux
      =+  (ecdsa-raw-sign:secp256k1:secp:crypto (swp 3 (shax (jam mid))) priv)
      (cat 8 s r)
    =/  mp=moderator-profile
      :*  mid  nid  pub  ''  fbps  stake  sig  desc  now.bowl  ==
    ::  store moderator private key for escrow signing
    =.  mod-keys.state  (~(put by mod-keys.state) mid priv)
    =/  result  (handle-command [%register-moderator mp])
    :_  +.result
    %+  weld  -.result
    (ok-response eyre-id)
  ::
  ++  handle-api-propose-escrow
    |=  [eyre-id=@ta jon=json]
    ^-  (quip card _this)
    =,  dejs:format
    =/  f  (ot ~['thread_id'^so moderator+so timeout+ni])
    =/  [tid-t=@t mod-t=@t timeout=@ud]  (f jon)
    =/  tid=@uv  (slav %uv tid-t)
    =/  mid=moderator-id  (slav %uv mod-t)
    =/  result  (handle-command [%propose-escrow tid mid (mul ~s1 timeout)])
    :_  +.result
    %+  weld  -.result
    (ok-response eyre-id)
  ::
  ++  handle-api-agree-escrow
    |=  [eyre-id=@ta jon=json]
    ^-  (quip card _this)
    =,  dejs:format
    =/  tid-t=@t  ((ot ~['thread_id'^so]) jon)
    =/  tid=@uv  (slav %uv tid-t)
    =/  result  (handle-command [%agree-escrow tid])
    :_  +.result
    %+  weld  -.result
    (ok-response eyre-id)
  ::
  ++  handle-api-fund-escrow
    |=  [eyre-id=@ta jon=json]
    ^-  (quip card _this)
    =,  dejs:format
    =/  f  (ot ~['thread_id'^so 'tx_hash'^so])
    =/  [tid-t=@t txh=@t]  (f jon)
    =/  tid=@uv  (slav %uv tid-t)
    =/  result  (handle-command [%fund-escrow tid txh])
    :_  +.result
    %+  weld  -.result
    (ok-response eyre-id)
  ::
  ++  handle-api-release-escrow
    |=  [eyre-id=@ta jon=json]
    ^-  (quip card _this)
    =,  dejs:format
    =/  tid-t=@t  ((ot ~['thread_id'^so]) jon)
    =/  tid=@uv  (slav %uv tid-t)
    ~&  [%silk-api %release-escrow tid %pre-sigs ~(wyt by (~(gut by escrow-sigs.state) tid ~))]
    =/  result  (handle-command [%release-escrow tid])
    :_  +.result
    %+  weld  -.result
    (ok-response eyre-id)
  ::
  ++  handle-api-refund-escrow
    |=  [eyre-id=@ta jon=json]
    ^-  (quip card _this)
    =,  dejs:format
    =/  tid-t=@t  ((ot ~['thread_id'^so]) jon)
    =/  tid=@uv  (slav %uv tid-t)
    ~&  [%silk-api %refund-escrow tid %pre-sigs ~(wyt by (~(gut by escrow-sigs.state) tid ~))]
    =/  result  (handle-command [%refund-escrow tid])
    :_  +.result
    %+  weld  -.result
    (ok-response eyre-id)
  ::
  ++  handle-api-sign-escrow
    |=  [eyre-id=@ta jon=json]
    ^-  (quip card _this)
    =/  parsed=[tid-t=@t act=@t]
      =,  dejs:format
      ((ot ~['thread_id'^so 'escrow_action'^so]) jon)
    =/  tid=@uv  (slav %uv tid-t.parsed)
    =/  act=@t  act.parsed
    =/  esc=(unit escrow-config)  (~(get by escrows.state) tid)
    ?~  esc
      :_(this (err-response eyre-id 'escrow not found'))
    ::  look up moderator private key
    =/  mod-priv=(unit @ux)  (~(get by mod-keys.state) moderator-id.u.esc)
    ?~  mod-priv
      :_(this (err-response eyre-id 'moderator key not found'))
    ::  destination from escrow-config wallets
    =/  to-addr=@t
      ?:  =('release' act)  seller-wallet.u.esc
      buyer-wallet.u.esc
    ::  build amino JSON sign doc and sign
    =/  sign-doc=@t
      %:  amino-json-sign-doc-send:multisig
        multisig-address.u.esc  to-addr
        amount.u.esc  '$sZ'
        200.000  200.000  'zenith-stage1'
        account-number.u.esc  sequence.u.esc
      ==
    =/  sig=@ux  (sign-multisig-part:multisig sign-doc u.mod-priv)
    ::  find moderator signer index
    =/  sorted-pks=(list @ux)
      (sort-pubkeys:multisig ~[buyer-pubkey.u.esc seller-pubkey.u.esc moderator-pubkey.u.esc])
    =/  mod-pub=@ux  moderator-pubkey.u.esc
    =/  mod-idx=@ud
      =/  pks  sorted-pks
      =/  idx=@ud  0
      |-
      ?~  pks  0
      ?:  =(i.pks mod-pub)  idx
      $(pks t.pks, idx +(idx))
    ::  store sig locally
    =/  updated-sigs=(map @ud @ux)
      (~(put by (~(gut by escrow-sigs.state) tid ~)) mod-idx sig)
    =.  escrow-sigs.state  (~(put by escrow-sigs.state) tid updated-sigs)
    ::  build skein message
    =/  esc-msg=silk-message
      ?:  =('release' act)
        [%escrow-sign-release tid sig mod-idx]
      [%escrow-sign-refund tid sig mod-idx]
    ::  broadcast sig to all peers via gossip (moderator has no direct routes)
    =/  broadcast-peers=(list @p)
      %+  murn  ~(tap in peers.state)
      |=(p=@p ?:(=(p our.bowl) ~ `p))
    ~&  [%silk-escrow %moderator-sign-broadcast %to (lent broadcast-peers) %action act]
    =/  sig-cards=(list card)
      %+  turn  broadcast-peers
      |=(p=@p (gossip-card our.bowl p esc-msg))
    :_  this
    (weld sig-cards (ok-response eyre-id))
  ::
  ++  handle-api-file-dispute
    |=  [eyre-id=@ta jon=json]
    ^-  (quip card _this)
    =/  [tid-t=@t reason=@t nym-t=@t]
      =,  dejs:format
      ((ot ~['thread_id'^so reason+so nym+so]) jon)
    =/  tid=@uv  (slav %uv tid-t)
    =/  nym=nym-id  (slav %uv nym-t)
    =/  thd=(unit silk-thread)  (~(get by threads.state) tid)
    ?~  thd
      :_(this (err-response eyre-id 'thread not found'))
    =/  off=(unit offer)
      =/  ms=(list silk-message)  messages.u.thd
      |-
      ?~  ms  ~
      ?:  ?=(%offer -.i.ms)  `+.i.ms
      $(ms t.ms)
    =/  dis=dispute
      :*  (sham [our.bowl now.bowl tid])
          tid
          ?~(off *offer-id id.u.off)
          nym
          reason
          ~
          now.bowl
      ==
    =/  result  (handle-command [%file-dispute dis])
    :_  +.result
    (weld -.result (ok-response eyre-id))
  ::
  ::  command handler (shared by poke and http post)
  ::
  ++  handle-command
    |=  cmd=silk-command
    ^-  (quip card _this)
    ?-  -.cmd
        %create-nym
      =/  id=nym-id  (sham [our.bowl now.bowl label.cmd])
      =/  seed=@ux  (shax (jam [id now.bowl eny.bowl]))
      =/  pub=@ux   `@ux`(puck:ed:crypto seed)
      =/  nym=pseudonym  [id label.cmd pub wallet.cmd now.bowl]
      =.  nyms.state  (~(put by nyms.state) id nym)
      =.  keys.state  (~(put by keys.state) id [pub seed])
      :-  [(event-card [%nym-created nym])]~
      this
    ::
        %drop-nym
      =.  nyms.state  (~(del by nyms.state) id.cmd)
      =.  keys.state  (~(del by keys.state) id.cmd)
      =.  routes.state  (~(del by routes.state) id.cmd)
      :-  [(event-card [%nym-dropped id.cmd])]~
      this
    ::
        %post-listing
      =.  listings.state  (~(put by listings.state) id.listing.cmd listing.cmd)
      ::  broadcast listing + seller route to all peers via skein
      =/  route=nym-route  [seller.listing.cmd our.bowl %silk-core]
      =/  active-peers=(list @p)
        %+  murn  ~(tap in peers.state)
        |=(p=@p ?:(=(p our.bowl) ~ `p))
      ~&  [%silk-gossip %broadcasting-listing id.listing.cmd %to-peers (lent active-peers)]
      =/  peer-cards=(list card)
        (turn active-peers |=(p=@p (gossip-card our.bowl p [%catalog [listing.cmd]~ [route]~])))
      :-  (weld [(event-card [%listing-posted listing.cmd])]~ peer-cards)
      this
    ::
        %retract-listing
      =.  listings.state  (~(del by listings.state) id.cmd)
      =.  inventory.state  (~(del by inventory.state) id.cmd)
      ::  broadcast retraction to all peers
      =/  active-peers=(list @p)
        %+  murn  ~(tap in peers.state)
        |=(p=@p ?:(=(p our.bowl) ~ `p))
      =/  peer-cards=(list card)
        (turn active-peers |=(p=@p (gossip-card our.bowl p [%listing-retracted id.cmd])))
      :-  (weld [(event-card [%listing-retracted id.cmd])]~ peer-cards)
      this
    ::
        %add-peer
      ?:  =(ship.cmd our.bowl)  `this
      =.  peers.state  (~(put in peers.state) ship.cmd)
      =/  our-listings=(list listing)  ~(val by listings.state)
      =/  our-routes=(list nym-route)
        %+  turn  ~(val by nyms.state)
        |=(n=pseudonym [id.n our.bowl %silk-core])
      ~&  [%silk-gossip %add-peer ship.cmd %sending (lent our-listings) %listings]
      :_  this
      :~  (event-card [%peer-added ship.cmd])
          (gossip-card our.bowl ship.cmd [%catalog our-listings our-routes])
          (gossip-card our.bowl ship.cmd [%catalog-request our.bowl])
      ==
    ::
        %drop-peer
      =.  peers.state  (~(del in peers.state) ship.cmd)
      :-  [(event-card [%peer-removed ship.cmd])]~
      this
    ::
        %sync-catalog
      ~&  [%silk-sync %peer-count ~(wyt in peers.state) %peers ~(tap in peers.state)]
      :_  this
      %+  turn  ~(tap in peers.state)
      |=(p=@p (gossip-card our.bowl p [%catalog-request our.bowl]))
    ::
        %send-offer
      =/  o=offer  offer.cmd
      =/  tid=thread-id  thread-id.o
      ~&  [%silk-send-offer %thread tid %listing listing-id.o %buyer buyer.o %seller seller.o]
      =/  existing  (~(get by threads.state) tid)
      =/  thd=silk-thread
        ?^  existing
          =/  nc=@ux  (advance-chain chain.u.existing %offer)
          u.existing(thread-status %open, messages [[%offer o] messages.u.existing], chain nc, updated-at now.bowl)
        =/  nc=@ux  (advance-chain `@ux`0 %offer)
        [tid listing-id.o buyer.o seller.o %open [[%offer o] ~] nc now.bowl now.bowl]
      =.  threads.state  (~(put by threads.state) tid thd)
      ::  ensure buyer route is stored and sent to seller
      =/  buyer-route=nym-route  [buyer.o our.bowl %silk-core]
      =.  routes.state  (~(put by routes.state) buyer.o buyer-route)
      =/  route=(unit nym-route)  (~(get by routes.state) seller.o)
      ~&  [%silk-send-offer %route-found ?=(^ route) %known-routes ~(wyt by routes.state)]
      =/  send-cards=(list card)
        ?~  route
          ~&  [%silk-warn %no-route-for-seller seller.o %known ~(key by routes.state)]
          ~
        :~  (skein-send-card our.bowl u.route [%offer o])
            (skein-send-card our.bowl u.route [%catalog ~ [buyer-route]~])
        ==
      ::  track for ack-based resend
      =?  pending-acks.state  ?=(^ route)
        =/  [hash=@ux pm=pending-msg]  (make-pending tid u.route [%offer o] now.bowl)
        (~(put by pending-acks.state) hash pm)
      ::  notify silk-market: create order
      =/  mkt-cards=(list card)
        [(market-create-card our.bowl tid listing-id.o buyer.o seller.o id.o amount.o currency.o)]~
      :-  ;:(weld [(event-card [%thread-opened thd])]~ send-cards mkt-cards)
      this
    ::
        %accept-offer
      =/  thd=(unit silk-thread)  (~(get by threads.state) thread-id.cmd)
      ?~  thd  `this
      ::  check and decrement inventory (absent or 0 = unlimited)
      =/  inv=@ud  (~(gut by inventory.state) listing-id.u.thd 0)
      ?:  ?&((gth inv 0) =(inv 0))  `this  ::  unreachable but safe
      =?  inventory.state  (gth inv 0)
        (~(put by inventory.state) listing-id.u.thd (dec inv))
      =/  acc=accept  [thread-id.cmd offer-id.cmd now.bowl]
      =/  nc=@ux  (advance-chain chain.u.thd %accept)
      =/  updated=silk-thread
        u.thd(thread-status %accepted, messages [[%accept acc] messages.u.thd], chain nc, updated-at now.bowl)
      =.  threads.state  (~(put by threads.state) thread-id.cmd updated)
      ::  send seller route alongside accept so buyer can reply
      =/  seller-route=nym-route  [seller.u.thd our.bowl %silk-core]
      =.  routes.state  (~(put by routes.state) seller.u.thd seller-route)
      =/  route=(unit nym-route)  (~(get by routes.state) buyer.u.thd)
      =/  send-cards=(list card)
        ?~  route  ~
        :~  (skein-send-card our.bowl u.route [%accept acc])
            (skein-send-card our.bowl u.route [%catalog ~ [seller-route]~])
        ==
      =?  pending-acks.state  ?=(^ route)
        =/  [hash=@ux pm=pending-msg]  (make-pending thread-id.cmd u.route [%accept acc] now.bowl)
        (~(put by pending-acks.state) hash pm)
      =/  mkt-cards=(list card)
        [(market-advance-card our.bowl thread-id.cmd %accepted)]~
      :-  ;:(weld [(event-card [%thread-updated thread-id.cmd %accepted])]~ send-cards mkt-cards)
      this
    ::
        %reject-offer
      =/  thd=(unit silk-thread)  (~(get by threads.state) thread-id.cmd)
      ?~  thd  `this
      =/  rej=reject  [thread-id.cmd offer-id.cmd reason.cmd now.bowl]
      =/  nc=@ux  (advance-chain chain.u.thd %reject)
      =/  updated=silk-thread
        u.thd(thread-status %cancelled, messages [[%reject rej] messages.u.thd], chain nc, updated-at now.bowl)
      =.  threads.state  (~(put by threads.state) thread-id.cmd updated)
      =/  route=(unit nym-route)  (~(get by routes.state) buyer.u.thd)
      =/  send-cards=(list card)
        ?~  route  ~
        [(skein-send-card our.bowl u.route [%reject rej])]~
      =/  mkt-cards=(list card)
        [(market-advance-card our.bowl thread-id.cmd %cancelled)]~
      ::  auto-refund escrow on rejection
      =/  refund-result=(quip card _this)
        =/  esc=(unit escrow-config)  (~(get by escrows.state) thread-id.cmd)
        =/  est=(unit escrow-st)  (~(get by escrow-status.state) thread-id.cmd)
        ?.  ?&  ?=(^ esc)
                ?=(^ est)
                ?=(?(%agreed %funded %refunding) u.est)
            ==
          `this
        ~&  [%silk-escrow %auto-refund-on-reject thread-id.cmd]
        (handle-command [%refund-escrow thread-id.cmd])
      =.  this  +.refund-result
      :-  ;:(weld [(event-card [%thread-updated thread-id.cmd %cancelled])]~ send-cards mkt-cards -.refund-result)
      this
    ::
        %cancel-thread
      =/  thd=(unit silk-thread)  (~(get by threads.state) thread-id.cmd)
      ?~  thd  `this
      ?:  ?=(?(%completed %cancelled %resolved) thread-status.u.thd)  `this
      ::  restore inventory if order was accepted (inventory was decremented)
      =?  inventory.state  ?=(%accepted thread-status.u.thd)
        =/  inv=@ud  (~(gut by inventory.state) listing-id.u.thd 0)
        ?:(=(inv 0) inventory.state (~(put by inventory.state) listing-id.u.thd +(inv)))
      =/  nc=@ux  (advance-chain chain.u.thd %reject)
      =/  rej=reject  [thread-id.cmd `@uv`0 reason.cmd now.bowl]
      =/  updated=silk-thread
        u.thd(thread-status %cancelled, messages [[%reject rej] messages.u.thd], chain nc, updated-at now.bowl)
      =.  threads.state  (~(put by threads.state) thread-id.cmd updated)
      ::  notify counterparty
      =/  counterparty=nym-id
        ?:  (~(has by nyms.state) seller.u.thd)  buyer.u.thd
        seller.u.thd
      =/  route=(unit nym-route)  (~(get by routes.state) counterparty)
      =/  send-cards=(list card)
        ?~  route  ~
        [(skein-send-card our.bowl u.route [%reject rej])]~
      =/  mkt-cards=(list card)
        [(market-advance-card our.bowl thread-id.cmd %cancelled)]~
      ::  auto-refund escrow on cancel
      =/  refund-result=(quip card _this)
        =/  esc=(unit escrow-config)  (~(get by escrows.state) thread-id.cmd)
        =/  est=(unit escrow-st)  (~(get by escrow-status.state) thread-id.cmd)
        ?.  ?&  ?=(^ esc)
                ?=(^ est)
                ?=(?(%agreed %funded %refunding) u.est)
            ==
          `this
        ~&  [%silk-escrow %auto-refund-on-cancel thread-id.cmd]
        (handle-command [%refund-escrow thread-id.cmd])
      =.  this  +.refund-result
      :-  ;:(weld [(event-card [%thread-updated thread-id.cmd %cancelled])]~ send-cards mkt-cards -.refund-result)
      this
    ::
        %send-invoice
      =/  thd=(unit silk-thread)  (~(get by threads.state) thread-id.invoice.cmd)
      ?~  thd  `this
      ::  block manual invoice when escrow is active (auto-invoiced on agree)
      =/  esc-st=(unit escrow-st)  (~(get by escrow-status.state) thread-id.invoice.cmd)
      ?:  ?=(^ esc-st)
        ~&  [%silk-invoice %blocked-escrow-active thread-id.invoice.cmd u.esc-st]
        `this
      =/  inv=invoice  invoice.cmd
      =/  nc=@ux  (advance-chain chain.u.thd %invoice)
      =/  updated=silk-thread
        u.thd(messages [[%invoice inv] messages.u.thd], chain nc, updated-at now.bowl)
      =.  threads.state  (~(put by threads.state) thread-id.inv updated)
      ::  send invoice to buyer with per-tx payment address
      =/  route=(unit nym-route)  (~(get by routes.state) buyer.u.thd)
      =/  send-cards=(list card)
        ?~  route  ~
        [(skein-send-card our.bowl u.route [%invoice inv])]~
      ::  notify market
      =/  mkt-cards=(list card)
        [(market-advance-card our.bowl thread-id.inv %invoiced)]~
      :-  ;:(weld [(event-card [%thread-updated thread-id.inv %accepted])]~ send-cards mkt-cards)
      this
    ::
        %submit-payment
      =/  thd=(unit silk-thread)  (~(get by threads.state) thread-id.payment-proof.cmd)
      ?~  thd  `this
      =/  pp=payment-proof  payment-proof.cmd
      =/  nc=@ux  (advance-chain chain.u.thd %payment-proof)
      =/  updated=silk-thread
        u.thd(thread-status %paid, messages [[%payment-proof pp] messages.u.thd], chain nc, updated-at now.bowl)
      =.  threads.state  (~(put by threads.state) thread-id.pp updated)
      =/  route=(unit nym-route)  (~(get by routes.state) seller.u.thd)
      =/  send-cards=(list card)
        ?~  route  ~
        [(skein-send-card our.bowl u.route [%payment-proof pp])]~
      =?  pending-acks.state  ?=(^ route)
        =/  [hash=@ux pm=pending-msg]  (make-pending thread-id.pp u.route [%payment-proof pp] now.bowl)
        (~(put by pending-acks.state) hash pm)
      ::  notify market
      =/  mkt-cards=(list card)
        [(market-advance-card our.bowl thread-id.pp %paid)]~
      ::  auto-fund escrow if active (transitions escrow-status to %funded)
      =/  has-esc-fund=?
        ?&  (~(has by escrows.state) thread-id.pp)
            ?=(^ (~(get by escrow-status.state) thread-id.pp))
            ?=(%agreed (need (~(get by escrow-status.state) thread-id.pp)))
        ==
      =?  escrow-status.state  has-esc-fund
        ~&  [%silk-escrow %auto-fund-on-payment thread-id.pp]
        (~(put by escrow-status.state) thread-id.pp %funded)
      =/  fund-cards=(list card)
        ?.  has-esc-fund  ~
        [(market-advance-card our.bowl thread-id.pp %escrowed)]~
      =/  query-cards=(list card)
        ?.  has-esc-fund  ~
        =/  esc=(unit escrow-config)  (~(get by escrows.state) thread-id.pp)
        ?~  esc  ~
        ?:  =('' multisig-address.u.esc)  ~
        :~  [%pass /zenith/query-account %agent [our.bowl %silk-zenith] %poke %noun !>([%query-escrow-account thread-id.pp multisig-address.u.esc])]
        ==
      :-  ;:(weld [(event-card [%thread-updated thread-id.pp %paid])]~ send-cards mkt-cards fund-cards query-cards)
      this
    ::
        %send-fulfillment
      =/  thd=(unit silk-thread)  (~(get by threads.state) thread-id.fulfillment.cmd)
      ?~  thd  `this
      =/  ful=fulfillment  fulfillment.cmd
      =/  nc=@ux  (advance-chain chain.u.thd %fulfill)
      =/  updated=silk-thread
        u.thd(thread-status %fulfilled, messages [[%fulfill ful] messages.u.thd], chain nc, updated-at now.bowl)
      =.  threads.state  (~(put by threads.state) thread-id.ful updated)
      =/  route=(unit nym-route)  (~(get by routes.state) buyer.u.thd)
      =/  send-cards=(list card)
        ?~  route  ~
        [(skein-send-card our.bowl u.route [%fulfill ful])]~
      =?  pending-acks.state  ?=(^ route)
        =/  [hash=@ux pm=pending-msg]  (make-pending thread-id.ful u.route [%fulfill ful] now.bowl)
        (~(put by pending-acks.state) hash pm)
      =/  mkt-cards=(list card)
        [(market-advance-card our.bowl thread-id.ful %fulfilled)]~
      :-  ;:(weld [(event-card [%thread-updated thread-id.ful %fulfilled])]~ send-cards mkt-cards)
      this
    ::
        %file-dispute
      =/  thd=(unit silk-thread)  (~(get by threads.state) thread-id.dispute.cmd)
      ?~  thd  `this
      =/  dis=dispute  dispute.cmd
      =/  nc=@ux  (advance-chain chain.u.thd %dispute)
      =/  updated=silk-thread
        u.thd(thread-status %disputed, messages [[%dispute dis] messages.u.thd], chain nc, updated-at now.bowl)
      =.  threads.state  (~(put by threads.state) thread-id.dis updated)
      =/  counter=nym-id
        ?:  =(plaintiff.dis buyer.u.thd)
          seller.u.thd
        buyer.u.thd
      =/  route=(unit nym-route)  (~(get by routes.state) counter)
      =/  send-cards=(list card)
        ?~  route  ~
        [(skein-send-card our.bowl u.route [%dispute dis])]~
      ::  send dispute directly to moderator via nym route
      =/  esc-for-dis=(unit escrow-config)  (~(get by escrows.state) thread-id.dis)
      =/  mod-cards=(list card)
        ?~  esc-for-dis  ~
        =/  dispute-msg=silk-message  [%escrow-dispute thread-id.dis dis]
        =/  mod=(unit moderator-profile)  (~(get by moderators.state) moderator-id.u.esc-for-dis)
        =/  mod-route=(unit nym-route)
          ?~(mod ~ (~(get by routes.state) nym-id.u.mod))
        =/  direct=(list card)
          ?~(mod-route ~ [(skein-send-card our.bowl u.mod-route dispute-msg)]~)
        =/  dpeers=(list @p)
          %+  murn  ~(tap in peers.state)
          |=(p=@p ?:(=(p our.bowl) ~ `p))
        ~&  [%silk-escrow %dispute-to-moderator %direct ?=(^ mod-route) %gossip-to (lent dpeers)]
        (weld direct (turn dpeers |=(p=@p (gossip-card our.bowl p dispute-msg))))
      =/  mkt-cards=(list card)
        [(market-advance-card our.bowl thread-id.dis %disputed)]~
      :-  ;:(weld [(event-card [%thread-updated thread-id.dis %disputed])]~ send-cards mod-cards mkt-cards)
      this
    ::
        %submit-verdict
      =/  thd=(unit silk-thread)  (~(get by threads.state) thread-id.verdict.cmd)
      ?~  thd  `this
      =/  ver=verdict  verdict.cmd
      =/  nc=@ux  (advance-chain chain.u.thd %verdict)
      =/  updated=silk-thread
        u.thd(thread-status %resolved, messages [[%verdict ver] messages.u.thd], chain nc, updated-at now.bowl)
      =.  threads.state  (~(put by threads.state) thread-id.ver updated)
      =/  mkt-cards=(list card)
        [(market-advance-card our.bowl thread-id.ver %resolved)]~
      :-  (weld [(event-card [%thread-updated thread-id.ver %resolved])]~ mkt-cards)
      this
    ::
        %register-moderator
      =/  mp=moderator-profile  moderator-profile.cmd
      =.  moderators.state  (~(put by moderators.state) id.mp mp)
      ::  broadcast profile + route to all peers
      =/  active-peers=(list @p)
        %+  murn  ~(tap in peers.state)
        |=(p=@p ?:(=(p our.bowl) ~ `p))
      =/  mod-route=nym-route  [nym-id.mp our.bowl %silk-core]
      =/  peer-cards=(list card)
        %-  zing
        %+  turn  active-peers
        |=  p=@p
        :~  (gossip-card our.bowl p [%moderator-profile mp])
            (gossip-card our.bowl p [%catalog ~ [mod-route]~])
        ==
      ~&  [%silk-moderator %registered-and-broadcast id.mp %nym nym-id.mp %to (lent active-peers) %peers]
      :-  (weld [(event-card [%moderator-registered mp])]~ peer-cards)
      this
    ::
        %retract-moderator
      =.  moderators.state  (~(del by moderators.state) id.cmd)
      =.  mod-keys.state  (~(del by mod-keys.state) id.cmd)
      =/  active-peers=(list @p)
        %+  murn  ~(tap in peers.state)
        |=(p=@p ?:(=(p our.bowl) ~ `p))
      =/  peer-cards=(list card)
        (turn active-peers |=(p=@p (gossip-card our.bowl p [%moderator-retracted id.cmd])))
      :-  (weld [(event-card [%moderator-retracted id.cmd])]~ peer-cards)
      this
    ::
        %propose-escrow
      =/  thd=(unit silk-thread)  (~(get by threads.state) thread-id.cmd)
      ?~  thd  `this
      =/  mod=(unit moderator-profile)  (~(get by moderators.state) moderator.cmd)
      ?~  mod  `this
      ::  reject if moderator is buyer or seller
      ?:  =(nym-id.u.mod buyer.u.thd)  `this
      ?:  =(nym-id.u.mod seller.u.thd)  `this
      ::  generate per-tx escrow key for this thread
      =/  [pub=@ux priv=@ux]
        =/  seed  (jam [our.bowl now.bowl eny.bowl thread-id.cmd %escrow])
        =/  pk=@ux  `@ux`(shax seed)
        =/  cpub=@ux  =+(secp256k1:secp:crypto (compress-point (priv-to-pub pk)))
        [cpub pk]
      =.  escrow-keys.state  (~(put by escrow-keys.state) thread-id.cmd priv)
      ::  create initial escrow config (seller pubkey TBD)
      =/  off=(unit offer)
        =/  ms=(list silk-message)  messages.u.thd
        |-
        ?~  ms  ~
        ?:  ?=(%offer -.i.ms)  `+.i.ms
        $(ms t.ms)
      ?~  off  `this
      ::  buyer-wallet from our local nym; seller-wallet filled on agree
      =/  buyer-nym=(unit pseudonym)  (~(get by nyms.state) buyer.u.thd)
      =/  esc=escrow-config
        :*  thread-id.cmd
            pub                      ::  buyer-pubkey
            0x0                      ::  seller-pubkey (TBD on agree)
            pubkey.u.mod             ::  moderator-pubkey
            id.u.mod                 ::  moderator-id
            ''                       ::  multisig-address (derived on agree)
            amount.u.off
            currency.u.off
            timeout.cmd
            fee-bps.u.mod
            0                        ::  account-number (filled on fund)
            0                        ::  sequence (0 for first tx)
            ?~(buyer-nym '' wallet.u.buyer-nym)
            ''                       ::  seller-wallet (filled on agree)
        ==
      =.  escrows.state  (~(put by escrows.state) thread-id.cmd esc)
      =.  escrow-status.state  (~(put by escrow-status.state) thread-id.cmd %proposed)
      ::  send proposal to seller over skein
      =/  route=(unit nym-route)  (~(get by routes.state) seller.u.thd)
      =/  send-cards=(list card)
        ?~  route  ~
        [(skein-send-card our.bowl u.route [%escrow-propose thread-id.cmd pub id.u.mod timeout.cmd ?~(buyer-nym '' wallet.u.buyer-nym)])]~
      =/  market-cards=(list card)
        [(market-advance-card our.bowl thread-id.cmd %escrow-proposed)]~
      :-  :(weld [(event-card [%escrow-proposed thread-id.cmd esc])]~ send-cards market-cards)
      this
    ::
        %agree-escrow
      =/  thd=(unit silk-thread)  (~(get by threads.state) thread-id.cmd)
      ?~  thd  `this
      =/  esc=(unit escrow-config)  (~(get by escrows.state) thread-id.cmd)
      ?~  esc  `this
      ::  generate per-tx escrow key
      =/  [pub=@ux priv=@ux]
        =/  seed  (jam [our.bowl now.bowl eny.bowl thread-id.cmd %escrow-agree])
        =/  pk=@ux  `@ux`(shax seed)
        =/  cpub=@ux  =+(secp256k1:secp:crypto (compress-point (priv-to-pub pk)))
        [cpub pk]
      =.  escrow-keys.state  (~(put by escrow-keys.state) thread-id.cmd priv)
      ::  derive real 2-of-3 multisig address; fill seller-wallet from local nym
      =/  seller-nym=(unit pseudonym)  (~(get by nyms.state) seller.u.thd)
      =/  addr=@t  (derive-multisig-address:multisig ~[buyer-pubkey.u.esc pub moderator-pubkey.u.esc])
      =/  updated=escrow-config
        u.esc(seller-pubkey pub, multisig-address addr, seller-wallet ?~(seller-nym '' wallet.u.seller-nym))
      =.  escrows.state  (~(put by escrows.state) thread-id.cmd updated)
      =.  escrow-status.state  (~(put by escrow-status.state) thread-id.cmd %agreed)
      ::  send agreement to buyer
      =/  route=(unit nym-route)  (~(get by routes.state) buyer.u.thd)
      =/  send-cards=(list card)
        ?~  route  ~
        [(skein-send-card our.bowl u.route [%escrow-agree thread-id.cmd pub ?~(seller-nym '' wallet.u.seller-nym)])]~
      ::  notify moderator: try direct route + gossip to all peers as fallback
      =/  mod=(unit moderator-profile)  (~(get by moderators.state) moderator-id.updated)
      =/  mod-route=(unit nym-route)  ?~(mod ~ (~(get by routes.state) nym-id.u.mod))
      =/  notify-msg=silk-message  [%escrow-notify updated buyer.u.thd seller.u.thd]
      =/  direct-cards=(list card)
        ?~  mod-route  ~
        [(skein-send-card our.bowl u.mod-route notify-msg)]~
      =/  gossip-peers=(list @p)
        %+  murn  ~(tap in peers.state)
        |=(p=@p ?:(=(p our.bowl) ~ `p))
      =/  gossip-cards=(list card)
        (turn gossip-peers |=(p=@p (gossip-card our.bowl p notify-msg)))
      ~&  [%silk-escrow %notify-moderator %mod-id moderator-id.updated %direct ?=(^ mod-route) %gossip-to (lent gossip-peers)]
      =/  mod-cards=(list card)  (weld direct-cards gossip-cards)
      =/  market-cards=(list card)
        [(market-advance-card our.bowl thread-id.cmd %escrow-agreed)]~
      ::  auto-send invoice with multisig address
      =/  off=(unit offer)  (find-offer messages.u.thd)
      ?~  off
        :-  :(weld [(event-card [%escrow-agreed thread-id.cmd multisig-address.updated])]~ send-cards mod-cards market-cards)
        this
      =/  escrow-fee=@ud  200.000
      =/  inv=invoice
        :*  (sham [our.bowl now.bowl thread-id.cmd])
            thread-id.cmd
            id.u.off
            seller.u.thd
            (add amount.u.off escrow-fee)
            currency.u.off
            multisig-address.updated
            (add now.bowl ~d7)
        ==
      ~&  [%silk-escrow %auto-invoice thread-id.cmd multisig-address.updated %amount (add amount.u.off escrow-fee)]
      =/  nc=@ux  (advance-chain chain.u.thd %invoice)
      =/  inv-thd=silk-thread
        u.thd(messages [[%invoice inv] messages.u.thd], chain nc, updated-at now.bowl)
      =.  threads.state  (~(put by threads.state) thread-id.cmd inv-thd)
      =/  buyer-route=(unit nym-route)  (~(get by routes.state) buyer.u.thd)
      =/  inv-cards=(list card)
        ?~  buyer-route  ~
        [(skein-send-card our.bowl u.buyer-route [%invoice inv])]~
      =/  inv-mkt=(list card)
        [(market-advance-card our.bowl thread-id.cmd %invoiced)]~
      :-  :(weld [(event-card [%escrow-agreed thread-id.cmd multisig-address.updated])]~ send-cards mod-cards market-cards inv-cards inv-mkt)
      this
    ::
        %fund-escrow
      =/  esc=(unit escrow-config)  (~(get by escrows.state) thread-id.cmd)
      ?~  esc  `this
      =.  escrow-status.state  (~(put by escrow-status.state) thread-id.cmd %funded)
      ::  notify counterparty
      =/  thd=(unit silk-thread)  (~(get by threads.state) thread-id.cmd)
      ?~  thd  `this
      =/  counter=nym-id  seller.u.thd
      =/  route=(unit nym-route)  (~(get by routes.state) counter)
      =/  send-cards=(list card)
        ?~  route  ~
        [(skein-send-card our.bowl u.route [%escrow-funded thread-id.cmd tx-hash.cmd])]~
      =/  mkt-cards=(list card)
        [(market-advance-card our.bowl thread-id.cmd %escrowed)]~
      ::  query multisig account number from chain
      =/  query-cards=(list card)
        ?:  =('' multisig-address.u.esc)  ~
        :~  [%pass /zenith/query-account %agent [our.bowl %silk-zenith] %poke %noun !>([%query-escrow-account thread-id.cmd multisig-address.u.esc])]
        ==
      :-  ;:(weld [(event-card [%escrow-funded thread-id.cmd])]~ send-cards mkt-cards query-cards)
      this
    ::
        %rebroadcast-escrow
      =/  tx-hex=@t  (~(gut by escrow-txhex.state) thread-id.cmd '')
      ?:  =('' tx-hex)  `this
      ~&  [%silk-escrow %rebroadcast thread-id.cmd]
      =/  broadcast-card=card
        [%pass /zenith/broadcast/[(scot %uv thread-id.cmd)] %agent [our.bowl %silk-zenith] %poke %noun !>([%broadcast-escrow thread-id.cmd tx-hex])]
      :-  [broadcast-card]~
      this
    ::
        %release-escrow
      =/  esc=(unit escrow-config)  (~(get by escrows.state) thread-id.cmd)
      ~&  [%silk-escrow %release-cmd %has-esc ?=(^ esc) %has-key ?=(^ (~(get by escrow-keys.state) thread-id.cmd))]
      ?~  esc  `this
      ::  block if account info not yet queried — set status and trigger query
      ?:  =(0 account-number.u.esc)
        ~&  [%silk-escrow %release-blocked %querying-account thread-id.cmd]
        =.  escrow-status.state  (~(put by escrow-status.state) thread-id.cmd %releasing)
        =/  query-cards=(list card)
          ?:  =('' multisig-address.u.esc)  ~
          :~  [%pass /zenith/query-account %agent [our.bowl %silk-zenith] %poke %noun !>([%query-escrow-account thread-id.cmd multisig-address.u.esc])]
          ==
        :-  query-cards
        this
      =/  priv=(unit @ux)  (~(get by escrow-keys.state) thread-id.cmd)
      ?~  priv  `this
      ::  find our signer index (based on sorted pubkey order)
      =/  sorted-pks=(list @ux)
        (sort-pubkeys:multisig ~[buyer-pubkey.u.esc seller-pubkey.u.esc moderator-pubkey.u.esc])
      =/  our-pub=@ux
        =+  secp256k1:secp:crypto
        (compress-point (priv-to-pub u.priv))
      =/  our-idx=@ud
        =/  pks  sorted-pks
        =/  idx=@ud  0
        |-
        ?~  pks  0  ::  fallback
        ?:  =(i.pks our-pub)  idx
        $(pks t.pks, idx +(idx))
      ::  release sends to seller's wallet (stored in escrow-config)
      =/  to-addr=@t  seller-wallet.u.esc
      =/  sign-doc=@t
        %:  amino-json-sign-doc-send:multisig
          multisig-address.u.esc  to-addr
          amount.u.esc  '$sZ'
          200.000  200.000  'zenith-stage1'
          account-number.u.esc  sequence.u.esc
        ==
      =/  sig=@ux  (sign-multisig-part:multisig sign-doc u.priv)
      =.  escrow-status.state  (~(put by escrow-status.state) thread-id.cmd %releasing)
      =/  existing=(map @ud @ux)  (~(gut by escrow-sigs.state) thread-id.cmd ~)
      =.  existing  (~(put by existing) our-idx sig)
      =.  escrow-sigs.state  (~(put by escrow-sigs.state) thread-id.cmd existing)
      ::  send sig to counterparty
      =/  thd=(unit silk-thread)  (~(get by threads.state) thread-id.cmd)
      ?~  thd  `this
      =/  we-are-seller=?  (~(has by nyms.state) seller.u.thd)
      =/  counter=nym-id  ?:(we-are-seller buyer.u.thd seller.u.thd)
      =/  route=(unit nym-route)  (~(get by routes.state) counter)
      ~&  [%silk-escrow %release-sign %idx our-idx %sigs ~(wyt by existing) %counter counter %has-route ?=(^ route)]
      =/  send-cards=(list card)
        ?~  route  ~
        [(skein-send-card our.bowl u.route [%escrow-sign-release thread-id.cmd sig our-idx])]~
      ::  check for local 2-sig assembly
      ?.  (gte ~(wyt by existing) 2)
        :-  (weld [(event-card [%escrow-releasing thread-id.cmd])]~ send-cards)
        this
      ::  2 sigs available locally — assemble and broadcast
      ~&  [%silk-escrow %release-local-assembly thread-id.cmd]
      =/  sig-pairs=(list [@ud @ux])
        %+  sort  ~(tap by existing)
        |=([a=[@ud @ux] b=[@ud @ux]] (lth -.a -.b))
      =/  signer-indices=(list @ud)  (turn sig-pairs |=([i=@ud s=@ux] i))
      =/  signatures=(list @ux)      (turn sig-pairs |=([i=@ud s=@ux] s))
      =/  tx-hex=@t
        %:  assemble-multisig-tx:multisig
          multisig-address.u.esc  to-addr
          amount.u.esc  '$sZ'
          200.000  200.000  'zenith-stage1'
          account-number.u.esc  sequence.u.esc
          sorted-pks  signer-indices  signatures
        ==
      ~&  [%silk-escrow %release-tx-assembled thread-id.cmd %hex-len (met 3 tx-hex)]
      =.  escrow-txhex.state  (~(put by escrow-txhex.state) thread-id.cmd tx-hex)
      =.  escrow-status.state  (~(put by escrow-status.state) thread-id.cmd %released)
      =/  broadcast-card=card
        [%pass /zenith/broadcast %agent [our.bowl %silk-zenith] %poke %noun !>([%broadcast-escrow thread-id.cmd tx-hex])]
      :-  ;:(weld [(event-card [%escrow-released thread-id.cmd])]~ send-cards [broadcast-card]~)
      this
    ::
        %refund-escrow
      =/  esc=(unit escrow-config)  (~(get by escrows.state) thread-id.cmd)
      ~&  [%silk-escrow %refund-cmd %has-esc ?=(^ esc) %has-key ?=(^ (~(get by escrow-keys.state) thread-id.cmd))]
      ?~  esc  `this
      ::  block if account info not yet queried — set status and trigger query
      ?:  =(0 account-number.u.esc)
        ~&  [%silk-escrow %refund-blocked %querying-account thread-id.cmd]
        =.  escrow-status.state  (~(put by escrow-status.state) thread-id.cmd %refunding)
        =/  query-cards=(list card)
          ?:  =('' multisig-address.u.esc)  ~
          :~  [%pass /zenith/query-account %agent [our.bowl %silk-zenith] %poke %noun !>([%query-escrow-account thread-id.cmd multisig-address.u.esc])]
          ==
        :-  query-cards
        this
      =/  priv=(unit @ux)  (~(get by escrow-keys.state) thread-id.cmd)
      ?~  priv  `this
      =/  sorted-pks=(list @ux)
        (sort-pubkeys:multisig ~[buyer-pubkey.u.esc seller-pubkey.u.esc moderator-pubkey.u.esc])
      =/  our-pub=@ux
        =+  secp256k1:secp:crypto
        (compress-point (priv-to-pub u.priv))
      =/  our-idx=@ud
        =/  pks  sorted-pks
        =/  idx=@ud  0
        |-
        ?~  pks  0
        ?:  =(i.pks our-pub)  idx
        $(pks t.pks, idx +(idx))
      =/  to-addr=@t  buyer-wallet.u.esc
      =/  sign-doc=@t
        %:  amino-json-sign-doc-send:multisig
          multisig-address.u.esc  to-addr
          amount.u.esc  '$sZ'
          200.000  200.000  'zenith-stage1'
          account-number.u.esc  sequence.u.esc
        ==
      =/  sig=@ux  (sign-multisig-part:multisig sign-doc u.priv)
      =.  escrow-status.state  (~(put by escrow-status.state) thread-id.cmd %refunding)
      =/  existing=(map @ud @ux)  (~(gut by escrow-sigs.state) thread-id.cmd ~)
      =.  existing  (~(put by existing) our-idx sig)
      =.  escrow-sigs.state  (~(put by escrow-sigs.state) thread-id.cmd existing)
      ::  send sig to counterparty
      =/  thd=(unit silk-thread)  (~(get by threads.state) thread-id.cmd)
      ?~  thd  `this
      =/  we-are-buyer=?  (~(has by nyms.state) buyer.u.thd)
      =/  counter=nym-id  ?:(we-are-buyer seller.u.thd buyer.u.thd)
      =/  route=(unit nym-route)  (~(get by routes.state) counter)
      ~&  [%silk-escrow %refund-sign %idx our-idx %sigs ~(wyt by existing) %counter counter %has-route ?=(^ route)]
      =/  send-cards=(list card)
        ?~  route  ~
        [(skein-send-card our.bowl u.route [%escrow-sign-refund thread-id.cmd sig our-idx])]~
      ::  check for local 2-sig assembly
      ?.  (gte ~(wyt by existing) 2)
        :-  (weld [(event-card [%escrow-refunding thread-id.cmd])]~ send-cards)
        this
      ::  2 sigs available locally — assemble and broadcast
      ~&  [%silk-escrow %refund-local-assembly thread-id.cmd]
      =/  sig-pairs=(list [@ud @ux])
        %+  sort  ~(tap by existing)
        |=([a=[@ud @ux] b=[@ud @ux]] (lth -.a -.b))
      =/  signer-indices=(list @ud)  (turn sig-pairs |=([i=@ud s=@ux] i))
      =/  signatures=(list @ux)      (turn sig-pairs |=([i=@ud s=@ux] s))
      =/  tx-hex=@t
        %:  assemble-multisig-tx:multisig
          multisig-address.u.esc  to-addr
          amount.u.esc  '$sZ'
          200.000  200.000  'zenith-stage1'
          account-number.u.esc  sequence.u.esc
          sorted-pks  signer-indices  signatures
        ==
      ~&  [%silk-escrow %refund-tx-assembled thread-id.cmd %hex-len (met 3 tx-hex)]
      =.  escrow-txhex.state  (~(put by escrow-txhex.state) thread-id.cmd tx-hex)
      =.  escrow-status.state  (~(put by escrow-status.state) thread-id.cmd %refunded)
      =/  broadcast-card=card
        [%pass /zenith/broadcast %agent [our.bowl %silk-zenith] %poke %noun !>([%broadcast-escrow thread-id.cmd tx-hex])]
      :-  ;:(weld [(event-card [%escrow-refunded thread-id.cmd])]~ send-cards [broadcast-card]~)
      this
    ==
  ::
  ::  json serializers
  ::
  ++  nym-to-json
    |=  n=pseudonym
    ^-  json
    %-  pairs:enjs:format
    :~  ['id' s+(scot %uv id.n)]
        ['label' s+label.n]
        ['pubkey' s+(scot %ux pubkey.n)]
        ['wallet' s+wallet.n]
        ['has_signing_key' b+(~(has by keys.state) id.n)]
        ['created_at' (numb:enjs:format (div (sub created-at.n ~1970.1.1) ~s1))]
    ==
  ::
  ++  listing-to-json
    |=  l=listing
    ^-  json
    =/  nym=(unit pseudonym)  (~(get by nyms.state) seller.l)
    ::  compute seller reputation from attestations
    =/  seller-rep=[total=@ud count=@ud]
      =/  atts=(list attestation)  ~(val by attestations.state)
      =/  acc=[total=@ud count=@ud]  [0 0]
      |-
      ?~  atts  acc
      ?:  =(subject.i.atts seller.l)
        $(atts t.atts, acc [(add total.acc score.i.atts) +(count.acc)])
      $(atts t.atts)
    %-  pairs:enjs:format
    :~  ['id' s+(scot %uv id.l)]
        ['seller' s+(scot %uv seller.l)]
        ['seller_label' ?~(nym ~ s+label.u.nym)]
        ['seller_wallet' ?~(nym ~ s+wallet.u.nym)]
        ['mine' b+?=(^ nym)]
        ['title' s+title.l]
        ['description' s+description.l]
        ['price' (numb:enjs:format price.l)]
        ['currency' s+currency.l]
        ['seller_score' (numb:enjs:format ?:(=(0 count.seller-rep) 0 (div total.seller-rep count.seller-rep)))]
        ['seller_reviews' (numb:enjs:format count.seller-rep)]
        ['inventory' (numb:enjs:format (~(gut by inventory.state) id.l 0))]
        ['created_at' (numb:enjs:format (div (sub created-at.l ~1970.1.1) ~s1))]
        :-  'expires_at'
        ?~  expires-at.l  ~
        (numb:enjs:format (div (sub u.expires-at.l ~1970.1.1) ~s1))
    ==
  ::
  ++  thread-to-json
    |=  t=silk-thread
    ^-  json
    =/  offer-data=[amount=@ud cur=@tas]
      =/  off  (find-offer messages.t)
      ?~(off [0 %$] [amount.u.off currency.u.off])
    %-  pairs:enjs:format
    =/  seller-nym=(unit pseudonym)  (~(get by nyms.state) seller.t)
    =/  buyer-nym=(unit pseudonym)   (~(get by nyms.state) buyer.t)
    :~  ['id' s+(scot %uv id.t)]
        ['listing_id' s+(scot %uv listing-id.t)]
        ['buyer' s+(scot %uv buyer.t)]
        ['seller' s+(scot %uv seller.t)]
        ['seller_wallet' ?~(seller-nym ~ s+wallet.u.seller-nym)]
        ['buyer_wallet' ?~(buyer-nym ~ s+wallet.u.buyer-nym)]
        ['status' s+`@t`thread-status.t]
        ['message_count' (numb:enjs:format (lent messages.t))]
        ['amount' (numb:enjs:format amount.offer-data)]
        ['currency' s+`@t`cur.offer-data]
        ['messages' [%a (turn (flop messages.t) message-to-json)]]
        ['chain' s+(scot %ux chain.t)]
        ['started_at' (numb:enjs:format (div (sub started-at.t ~1970.1.1) ~s1))]
        ['updated_at' (numb:enjs:format (div (sub updated-at.t ~1970.1.1) ~s1))]
        :-  'verification'
        =/  ver=(unit [verified=? balance=@ud checked-at=@da])
          (~(get by verifications.state) id.t)
        ?~  ver  ~
        %-  pairs:enjs:format
        :~  ['verified' b+verified.u.ver]
            ['balance' (numb:enjs:format balance.u.ver)]
            ['checked_at' (numb:enjs:format (div (sub checked-at.u.ver ~1970.1.1) ~s1))]
        ==
    ==
  ::
  ++  message-to-json
    |=  m=silk-message
    ^-  json
    ?+  -.m
      (pairs:enjs:format ~[['type' s+`@t`-.m]])
    ::
        %offer
      =/  o=offer  +.m
      %-  pairs:enjs:format
      :~  ['type' s+'offer']
          ['buyer' s+(scot %uv buyer.o)]
          ['seller' s+(scot %uv seller.o)]
          ['amount' (numb:enjs:format amount.o)]
          ['currency' s+`@t`currency.o]
          ['note' s+note.o]
          ['at' (numb:enjs:format (div (sub offered-at.o ~1970.1.1) ~s1))]
      ==
    ::
        %accept
      =/  a=accept  +.m
      %-  pairs:enjs:format
      :~  ['type' s+'accept']
          ['at' (numb:enjs:format (div (sub accepted-at.a ~1970.1.1) ~s1))]
      ==
    ::
        %reject
      =/  r=reject  +.m
      %-  pairs:enjs:format
      :~  ['type' s+'reject']
          ['reason' s+reason.r]
          ['at' (numb:enjs:format (div (sub rejected-at.r ~1970.1.1) ~s1))]
      ==
    ::
        %invoice
      =/  inv=invoice  +.m
      %-  pairs:enjs:format
      :~  ['type' s+'invoice']
          ['amount' (numb:enjs:format amount.inv)]
          ['currency' s+`@t`currency.inv]
          ['pay_address' s+pay-address.inv]
          ['expires_at' (numb:enjs:format (div (sub expires-at.inv ~1970.1.1) ~s1))]
      ==
    ::
        %payment-proof
      =/  pp=payment-proof  +.m
      %-  pairs:enjs:format
      :~  ['type' s+'payment-proof']
          ['tx_hash' s+tx-hash.pp]
          ['at' (numb:enjs:format (div (sub paid-at.pp ~1970.1.1) ~s1))]
      ==
    ::
        %fulfill
      =/  f=fulfillment  +.m
      %-  pairs:enjs:format
      :~  ['type' s+'fulfill']
          ['note' s+note.f]
          ['at' (numb:enjs:format (div (sub fulfilled-at.f ~1970.1.1) ~s1))]
      ==
    ::
        %complete
      %-  pairs:enjs:format
      :~  ['type' s+'complete']
          ['at' (numb:enjs:format (div (sub completed-at.+.m ~1970.1.1) ~s1))]
      ==
    ::
        %direct-message
      %-  pairs:enjs:format
      :~  ['type' s+'direct-message']
          ['sender' s+(scot %uv sender.+.m)]
          ['text' s+text.+.m]
          ['at' (numb:enjs:format (div (sub sent-at.+.m ~1970.1.1) ~s1))]
      ==
    ::
        %dispute
      =/  d=dispute  +.m
      %-  pairs:enjs:format
      :~  ['type' s+'dispute']
          ['reason' s+reason.d]
          ['at' (numb:enjs:format (div (sub filed-at.d ~1970.1.1) ~s1))]
      ==
    ::
        %verdict
      =/  v=verdict  +.m
      %-  pairs:enjs:format
      :~  ['type' s+'verdict']
          ['ruling' s+`@t`ruling.v]
          ['note' s+note.v]
          ['at' (numb:enjs:format (div (sub ruled-at.v ~1970.1.1) ~s1))]
      ==
    ::
        %attest
      =/  a=attestation  +.m
      %-  pairs:enjs:format
      :~  ['type' s+'attest']
          ['subject' s+(scot %uv subject.a)]
          ['score' (numb:enjs:format score.a)]
          ['note' s+note.a]
          ['at' (numb:enjs:format (div (sub issued-at.a ~1970.1.1) ~s1))]
      ==
    ==
  --
::
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  (on-peek:def path)
      [%x %nyms ~]
    ``noun+!>(~(val by nyms.state))
  ::
      [%x %listings ~]
    ``noun+!>(~(val by listings.state))
  ::
      [%x %threads ~]
    ``noun+!>(~(val by threads.state))
  ::
      [%x %thread * ~]
    =/  tid=@uv  (slav %uv i.t.t.path)
    ``noun+!>((~(get by threads.state) tid))
  ::
      [%x %peers ~]
    ``noun+!>(peers.state)
  ::
      [%x %stats ~]
    =/  s
      :*  nyms=~(wyt by nyms.state)
          listings=~(wyt by listings.state)
          threads=~(wyt by threads.state)
          routes=~(wyt by routes.state)
          peers=~(wyt in peers.state)
      ==
    ``noun+!>(s)
  ::
      [%x %escrow-debug %json ~]
    =/  entries=(list json)
      %+  turn  ~(tap by escrows.state)
      |=  [tid=@uv esc=escrow-config]
      =/  est=(unit escrow-st)  (~(get by escrow-status.state) tid)
      =/  sigs=(map @ud @ux)  (~(gut by escrow-sigs.state) tid ~)
      =/  has-key=?  (~(has by escrow-keys.state) tid)
      =/  txhex=@t  (~(gut by escrow-txhex.state) tid '')
      %-  pairs:enjs:format
      :~  ['thread_id' s+(scot %uv tid)]
          ['escrow_status' ?~(est ~ s+`@t`u.est)]
          ['sigs_count' (numb:enjs:format ~(wyt by sigs))]
          ['has_escrow_key' b+has-key]
          ['multisig_address' s+multisig-address.esc]
          ['moderator_id' s+(scot %uv moderator-id.esc)]
          ['buyer_pubkey' s+(scot %ux buyer-pubkey.esc)]
          ['seller_pubkey' s+(scot %ux seller-pubkey.esc)]
          ['mod_pubkey' s+(scot %ux moderator-pubkey.esc)]
          ['buyer_wallet' s+buyer-wallet.esc]
          ['seller_wallet' s+seller-wallet.esc]
          ['amount' (numb:enjs:format amount.esc)]
          ['has_tx_hex' b+!=('' txhex)]
          :-  'sig_indices'
          [%a (turn ~(tap by sigs) |=([idx=@ud sig=@ux] (numb:enjs:format idx)))]
      ==
    =/  result=json
      %-  pairs:enjs:format
      :~  ['escrows' [%a entries]]
          ['escrow_count' (numb:enjs:format ~(wyt by escrows.state))]
          ['escrow_status_count' (numb:enjs:format ~(wyt by escrow-status.state))]
          ['escrow_keys_count' (numb:enjs:format ~(wyt by escrow-keys.state))]
          ['escrow_sigs_count' (numb:enjs:format ~(wyt by escrow-sigs.state))]
          ['mod_keys_count' (numb:enjs:format ~(wyt by mod-keys.state))]
          ['moderators_count' (numb:enjs:format ~(wyt by moderators.state))]
      ==
    ``json+!>(result)
  ==
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+  path  (on-watch:def path)
      [%events ~]
    `this
  ::
      [%http-response @ ~]
    `this
  ==
::
++  on-leave  on-leave:def
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ?+  wire  (on-agent:def wire sign)
      [%silk *]
    ?:  ?=(%poke-ack -.sign)
      ?~  p.sign  `this
      ~&  [%silk-poke-failed wire]
      ((slog u.p.sign) `this)
    `this
  ::
      [%zenith-pay @ ~]
    ?.  ?=(%poke-ack -.sign)  `this
    =/  tid=@uv  (slav %uv i.t.wire)
    ?^  p.sign
      ~&  [%silk-pay %send-poke-failed tid]
      ((slog u.p.sign) `this)
    ~&  [%silk-pay %send-poke-accepted tid]
    `this
  ::
      [%zenith-addr @ ~]
    ?.  ?=(%poke-ack -.sign)  `this
    ?^  p.sign
      ~&  [%silk-zenith-addr %poke-failed wire]
      ((slog u.p.sign) `this)
    ::  zenith processed add-account — scry the address out
    =/  tid=@uv  (slav %uv i.t.wire)
    =/  acc-name=@t  (scot %uv tid)
    ~&  [%silk-zenith-addr %scrying-account acc-name]
    =/  result
      .^(* %gx /(scot %p our.bowl)/zenith/(scot %da now.bowl)/account/[acc-name]/noun)
    =/  acc=(unit [addr=@t @ux @ux @ud @ud])
      ;;((unit [addr=@t @ux @ux @ud @ud]) result)
    ?~  acc
      ~&  [%silk-zenith-addr %account-not-found acc-name]
      `this
    =/  addr=@t  -.u.acc
    ~&  [%silk-zenith-addr %got-address tid addr]
    ::  construct invoice with per-tx address and send
    =/  thd=(unit silk-thread)  (~(get by threads.state) tid)
    ?~  thd
      ~&  [%silk-zenith-addr %thread-gone tid]
      `this
    =/  off=(unit offer)  (find-offer messages.u.thd)
    ?~  off
      ~&  [%silk-zenith-addr %no-offer tid]
      `this
    =/  inv=invoice
      :*  (sham [our.bowl now.bowl tid])
          tid
          id.u.off
          seller.u.thd
          amount.u.off
          currency.u.off
          addr
          (add now.bowl ~d7)
      ==
    ::  inline send-invoice logic (handle-command is scoped in on-poke)
    =/  nc=@ux  (advance-chain chain.u.thd %invoice)
    =/  updated=silk-thread
      u.thd(messages [[%invoice inv] messages.u.thd], chain nc, updated-at now.bowl)
    =.  threads.state  (~(put by threads.state) tid updated)
    =/  route=(unit nym-route)  (~(get by routes.state) buyer.u.thd)
    =/  send-cards=(list card)
      ?~  route  ~
      [(skein-send-card our.bowl u.route [%invoice inv])]~
    =/  mkt-cards=(list card)
      [(market-advance-card our.bowl tid %invoiced)]~
    :-  ;:(weld [(event-card [%thread-updated tid %accepted])]~ send-cards mkt-cards)
    this
  ::
      [%market *]
    ?-  -.sign
        %poke-ack
      ?~  p.sign  `this
      ~&  [%silk-market-poke-failed wire]
      ((slog u.p.sign) `this)
    ::
        %fact
      ?.  =(%noun p.cage.sign)  `this
      =/  raw  q.q.cage.sign
      ~&  [%silk-market-event ?:(?=(@ raw) raw -.raw)]
      ?:  ?=([%invalid-transition @ @ @] raw)
        ~&  [%silk-market %invalid-transition +.raw]
        `this
      ?:  ?=([%order-completed @ @ @] raw)
        ~&  [%silk-market %order-completed +.raw]
        `this
      `this
    ::
        %kick
      :_  this
      :~  [%pass /market/events %agent [our.bowl %silk-market] %watch /market-events]
      ==
    ::
        %watch-ack
      ?~  p.sign  `this
      ((slog u.p.sign) `this)
    ==
  ::
      [%zenith *]
    ?-  -.sign
        %poke-ack
      ?~  p.sign  `this
      ~&  [%silk-zenith-poke-failed wire]
      ((slog u.p.sign) `this)
    ::
        %fact
      ?.  =(%noun p.cage.sign)  `this
      =/  raw  q.q.cage.sign
      ~&  [%silk-zenith-event ?:(?=(@ raw) raw -.raw)]
      ::  on payment confirmed: advance market to escrowed
      ?:  ?=([%payment-confirmed @ @] raw)
        =/  tid=@uv  ;;(@uv +<.raw)
        ~&  [%silk-zenith %payment-confirmed tid]
        :_  this
        [(market-advance-card our.bowl tid %escrowed)]~
      `this
    ::
        %kick
      :_  this
      :~  [%pass /zenith/events %agent [our.bowl %silk-zenith] %watch /zenith-events]
      ==
    ::
        %watch-ack
      ?~  p.sign  `this
      ((slog u.p.sign) `this)
    ==
  ==
++  on-arvo
  |=  [=wire sign=sign-arvo]
  ^-  (quip card _this)
  ?+  wire  (on-arvo:def wire sign)
      [%eyre *]
    `this
  ::
      [%silk %resend ~]
    ::  process pending acks: resend or expire
    =/  now=@da  now.bowl
    =/  to-resend=(list [hash=@ux pm=pending-msg])
      %+  murn  ~(tap by pending-acks.state)
      |=  [hash=@ux pm=pending-msg]
      ?:  (gte attempts.pm max-resend)  ~   ::  expired, will be pruned
      =/  backoff=@dr  (mul resend-base (bex attempts.pm))
      ?.  (gte now (add sent-at.pm backoff))  ~  ::  not time yet
      `[hash pm]
    ::  prune expired entries
    =.  pending-acks.state
      =/  expired=(list @ux)
        %+  murn  ~(tap by pending-acks.state)
        |=  [hash=@ux pm=pending-msg]
        ?:  (gte attempts.pm max-resend)  `hash
        ~
      =/  pa  pending-acks.state
      =/  ex  expired
      |-
      ?~  ex  pa
      $(ex t.ex, pa (~(del by pa) i.ex))
    ::  resend and bump attempts
    =/  resend-cards=(list card)
      %+  turn  to-resend
      |=  [hash=@ux pm=pending-msg]
      (skein-send-card our.bowl target.pm msg.pm)
    =.  pending-acks.state
      %-  ~(gas by pending-acks.state)
      %+  turn  to-resend
      |=  [hash=@ux pm=pending-msg]
      [hash pm(attempts +(attempts.pm), sent-at now)]
    ::  reschedule timer
    :-  (snoc resend-cards [%pass /silk/resend %arvo %b %wait (add now resend-period)])
    this
  ::
      [%zenith-check @ ~]
    =/  tid=@uv  (slav %uv i.t.wire)
    ?.  ?=([%khan %arow *] sign)
      ~&  [%silk-verify %unexpected-sign wire]
      `this
    ?:  ?=(%| -.p.sign)
      ~&  [%silk-verify %thread-failed tid p.p.sign]
      `this
    ::  parse balance result: (list [denom=@t amount=@ud])
    ::  q.p.p.sign is the vase [type noun]; q.q.p.p.sign is the raw noun
    =/  bals=(list [denom=@t amount=@ud])
      ;;((list [denom=@t amount=@ud]) q.q.p.p.sign)
    ::  find sZ/znt balance
    =/  bal=@ud
      =/  items=(list [denom=@t amount=@ud])  bals
      |-
      ?~  items  0
      ?:  |(=('znt' denom.i.items) =('sZ' denom.i.items) =('sz' denom.i.items) =('$sZ' denom.i.items) =('$sz' denom.i.items))
        amount.i.items
      $(items t.items)
    ::  look up invoice amount for this thread
    =/  thd=(unit silk-thread)  (~(get by threads.state) tid)
    =/  inv-amount=@ud
      ?~  thd  0
      =/  inv=(unit invoice)  (find-invoice messages.u.thd)
      ?~(inv 0 amount.u.inv)
    ::  verified if balance >= invoice amount
    =/  verified=?  (gte bal inv-amount)
    ~&  [%silk-verify tid %balance bal %required inv-amount %verified verified]
    =.  verifications.state
      (~(put by verifications.state) tid [verified bal now.bowl])
    `this
  ::
      [%zenith-poll @ ~]
    ::  poll balance on pay address to confirm auto-payment
    =/  tid=@uv  (slav %uv i.t.wire)
    =/  thd=(unit silk-thread)  (~(get by threads.state) tid)
    ?~  thd
      ~&  [%silk-pay-poll %thread-gone tid]
      `this
    ::  if already paid, stop polling
    ?:  =(%paid thread-status.u.thd)
      ~&  [%silk-pay-poll %already-paid tid]
      `this
    =/  inv=(unit invoice)  (find-invoice messages.u.thd)
    ?~  inv
      ~&  [%silk-pay-poll %no-invoice tid]
      `this
    =/  pay-addr=@t  pay-address.u.inv
    ?:  =('' pay-addr)
      ~&  [%silk-pay-poll %no-pay-addr tid]
      `this
    ~&  [%silk-pay-poll %checking tid pay-addr]
    ::  fire balance check
    =/  khan-card=card
      [%pass /zenith-check/(scot %uv tid) %arvo %k %fard %zenith %get-balances-by-addr %noun !>(pay-addr)]
    ::  check existing verification — if confirmed, auto-submit payment
    =/  ver=(unit [verified=? balance=@ud checked-at=@da])
      (~(get by verifications.state) tid)
    ?:  ?&  ?=(^ ver)
             verified.u.ver
         ==
      ::  payment verified — auto-submit (inlined from %submit-payment)
      ~&  [%silk-pay-poll %verified tid %auto-submitting]
      =/  pp=payment-proof  [tid id.u.inv 'auto-pay-via-zenith' now.bowl]
      =/  nc=@ux  (advance-chain chain.u.thd %payment-proof)
      =/  updated=silk-thread
        u.thd(thread-status %paid, messages [[%payment-proof pp] messages.u.thd], chain nc, updated-at now.bowl)
      =.  threads.state  (~(put by threads.state) tid updated)
      =/  route=(unit nym-route)  (~(get by routes.state) seller.u.thd)
      =/  send-cards=(list card)
        ?~  route  ~
        [(skein-send-card our.bowl u.route [%payment-proof pp])]~
      =?  pending-acks.state  ?=(^ route)
        =/  [hash=@ux pm=pending-msg]  (make-pending tid u.route [%payment-proof pp] now.bowl)
        (~(put by pending-acks.state) hash pm)
      =/  mkt-cards=(list card)
        [(market-advance-card our.bowl tid %paid)]~
      ::  auto-fund escrow if active
      =/  has-esc-fund=?
        ?&  (~(has by escrows.state) tid)
            ?=(^ (~(get by escrow-status.state) tid))
            ?=(%agreed (need (~(get by escrow-status.state) tid)))
        ==
      =?  escrow-status.state  has-esc-fund
        ~&  [%silk-escrow %auto-fund-on-poll-payment tid]
        (~(put by escrow-status.state) tid %funded)
      =/  fund-cards=(list card)
        ?.  has-esc-fund  ~
        [(market-advance-card our.bowl tid %escrowed)]~
      =/  query-cards=(list card)
        ?.  has-esc-fund  ~
        =/  esc=(unit escrow-config)  (~(get by escrows.state) tid)
        ?~  esc  ~
        ?:  =('' multisig-address.u.esc)  ~
        :~  [%pass /zenith/query-account %agent [our.bowl %silk-zenith] %poke %noun !>([%query-escrow-account tid multisig-address.u.esc])]
        ==
      :-  ;:(weld [khan-card]~ [(event-card [%thread-updated tid %paid])]~ send-cards mkt-cards fund-cards query-cards)
      this
    ::  not yet confirmed — keep polling (up to 5min = 30 polls)
    =/  poll-card=card
      [%pass /zenith-poll/(scot %uv tid) %arvo %b %wait (add now.bowl ~s10)]
    :-  ~[khan-card poll-card]
    this
  ==
++  on-fail   on-fail:def
--
