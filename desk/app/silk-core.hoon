::  %silk-core: private commerce protocol agent
::
::  all peer messaging goes through %skein.
::  this agent never does direct ship-to-ship communication.
::  serves HTTP JSON API at /apps/silk/api/ for the frontend.
::
/-  *silk
/+  dbug, verb, default-agent, server, multisig
|%
::
+$  pending-msg
  $:  msg-hash=@ux
      thread-id=@uv
      target=@ux
      msg=silk-message
      sent-at=@da
      attempts=@ud
      sender=nym-id
  ==
::
+$  state-0
  $:  %0
      nyms=(map nym-id pseudonym)
      listings=(map listing-id listing)
      threads=(map thread-id silk-thread)
      contacts=(map nym-id @ux)
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
      mod-keys=(map moderator-id @ux)
      escrow-txhex=(map thread-id @t)
      our-bundles=(map nym-id @ux)
      bundle-minted-at=@da
      known-keys=(map nym-id @ux)
      pending-proposals=(map @uv pending-proposal)
      awaiting-mod-contact=(map thread-id pending-mod-delivery)
      evidence-store=(map @uv evidence)
      nym-intro-seqs=(map nym-id @ud)
      processed-msg-ids=(set @ux)
  ==
::
+$  current-state  state-0
+$  card  card:agent:gall
::
++  max-resend   3          ::  max resend attempts
++  resend-base  ~m1        ::  base backoff for resends
++  resend-period  ~m2      ::  how often to check pending acks
::
++  seller-of-thread
  |=  [tid=@uv threads=(map @uv silk-thread)]
  ^-  nym-id
  =/  thd=(unit silk-thread)  (~(get by threads) tid)
  ?~  thd  *nym-id
  seller.u.thd
::
++  buyer-of-thread
  |=  [tid=@uv threads=(map @uv silk-thread)]
  ^-  nym-id
  =/  thd=(unit silk-thread)  (~(get by threads) tid)
  ?~  thd  *nym-id
  buyer.u.thd
::
++  default-nym
  |=  nyms=(map nym-id pseudonym)
  ^-  nym-id
  =/  vals=(list pseudonym)  ~(val by nyms)
  ?~  vals  *nym-id
  id.i.vals
::
++  skein-app  %silk-core
::
++  skein-send-card
  |=  [our=ship contact=@ux reply=(unit @ux) sender=nym-id keys=(map nym-id nym-keypair) msg=silk-message]
  ^-  card
  =/  sig=@ux
    =/  kp=(unit nym-keypair)  (~(get by keys) sender)
    ?~  kp  0x0
    (sign:ed:crypto (jam msg) sec.u.kp)
  =/  pkt=silk-packet  [sender sig reply msg]
  =/  req
    :*  skein-app
        [%contact contact]
        (jam pkt)
        [~ ~ ~]
    ==
  [%pass /silk/send %agent [our %skein] %poke %skein-send !>(req)]
::
++  gossip-card
  |=  [our=ship target-ship=@p reply=(unit @ux) sender=nym-id keys=(map nym-id nym-keypair) msg=silk-message]
  ^-  card
  =/  sig=@ux
    =/  kp=(unit nym-keypair)  (~(get by keys) sender)
    ?~  kp  0x0
    (sign:ed:crypto (jam msg) sec.u.kp)
  =/  pkt=silk-packet  [sender sig reply msg]
  =/  req
    :*  skein-app
        [%endpoint [target-ship %silk-core]]
        (jam pkt)
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
  |=  [tid=@uv target=@ux msg=silk-message now=@da actor=nym-id]
  ^-  [hash=@ux pm=pending-msg]
  =/  hash=@ux  `@ux`(sham msg)
  [hash [hash tid target msg now 0 actor]]
::
::  WS1: poke silk-market to create or advance an order (propose-based, atomic)
::
++  market-create-card
  |=  [our=ship pid=@uv tid=@uv lid=listing-id buyer=nym-id seller=nym-id oid=offer-id amount=@ud currency=@tas]
  ^-  card
  [%pass /market/propose %agent [our %silk-market] %poke %noun !>([%propose-create pid tid lid buyer seller oid amount currency])]
::
++  market-advance-card
  |=  [our=ship pid=@uv tid=@uv to=@tas]
  ^-  card
  [%pass /market/propose %agent [our %silk-market] %poke %noun !>([%propose-advance pid tid to])]
::
::  WS1: stage a proposal — store staged thread + cards, send only the market poke
::  returns the proposal-id and the market poke card
::
++  stage-proposal
  |=  $:  our=ship
          now=@da
          tid=@uv
          thd=silk-thread
          outbound=(list card)
          events=(list card)
          actor=nym-id
          proposals=(map @uv pending-proposal)
          ::  staged side-effect mutations
          s-pend-acks=(list [@ux pending-msg-entry])
          s-inventory=(list [listing-id @ud])
          s-escrow-st=(list [@uv escrow-st])
          s-escrow-sigs=(list [@uv (map @ud @ux)])
          s-escrow-keys=(list [@uv @ux])
          ::  market-card builder: takes pid, returns card
          build-market-card=$-([@uv] card)
      ==
  ^-  [pid=@uv proposals=(map @uv pending-proposal) cards=(list card)]
  =/  pid=@uv  (sham [tid now actor])
  =/  mkt-card=card  (build-market-card pid)
  =/  pp=pending-proposal
    [pid [tid thd] outbound events actor s-pend-acks s-inventory s-escrow-st s-escrow-sigs s-escrow-keys]
  [pid (~(put by proposals) pid pp) [mkt-card]~]
::
::  WS5: compute idempotence key for a message
::
++  msg-id
  |=  msg=silk-message
  ^-  @ux
  `@ux`(sham msg)
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
::
::  probe skein relay list for potential silk peers
::  sends catalog-request to each known skein ship that isn't already a peer
::
++  discover-peers-cards
  |=  [our=ship now=@da peers=(set @p) nyms=(map nym-id pseudonym) keys=(map nym-id nym-keypair) bundles=(map nym-id @ux)]
  ^-  (list card)
  =/  relay-result
    (mule |.(.^(* %gx /(scot %p our)/skein/(scot %da now)/descriptors/noun)))
  ?:  ?=(%| -.relay-result)  ~
  ::  extract ship set from raw descriptor list
  =/  ships=(set @p)
    =/  raw  p.relay-result
    =/  acc=(set @p)  ~
    |-
    ?@  raw  acc
    ?@  -.raw  $(raw +.raw)
    ::  each descriptor is [relay ship pub weight ...]
    ::  ship is at +<
    =/  try  (mule |.(;;(@p +<.-.raw)))
    =?  acc  ?=(%& -.try)  (~(put in acc) p.try)
    $(raw +.raw)
  =/  new-ships=(list @p)
    %+  murn  ~(tap in ships)
    |=  s=@p
    ?:  =(s our)  ~
    ?:  (~(has in peers) s)  ~
    `s
  ::  WS2: catalog-request now uses request-id + reply-contact
  =/  dn=nym-id  (default-nym nyms)
  =/  reply-bundle=(unit @ux)  (~(get by bundles) dn)
  ?~  reply-bundle  ~
  %+  turn  new-ships
  |=  s=@p
  =/  rid=@uv  (sham [our now s])
  (gossip-card our s reply-bundle dn keys [%catalog-request rid u.reply-bundle])
::
::  Fix 2: mint contact bundle for a single nym
::
++  mint-nym-card
  |=  [our=ship nid=nym-id]
  ^-  card
  [%pass /silk/mint-contact/(scot %uv nid) %agent [our %skein] %poke %skein-admin !>([%mint-contact %silk-core nid])]
::
::  Fix 2: mint cards for all existing nyms
::
++  mint-all-nyms-cards
  |=  [our=ship nyms=(map nym-id pseudonym)]
  ^-  (list card)
  (turn ~(tap in ~(key by nyms)) |=(nid=nym-id (mint-nym-card our nid)))
::
::  strip wallet addresses from escrow-config for moderator notification
::
++  escrow-notify-from-config
  |=  esc=escrow-config
  ^-  escrow-notify-data
  :*  thread-id.esc
      buyer-pubkey.esc
      seller-pubkey.esc
      moderator-pubkey.esc
      moderator-id.esc
      multisig-address.esc
      amount.esc
      currency.esc
      timeout.esc
      moderator-fee-bps.esc
  ==
::
::
::  WS1: determine the correct actor nym for an outbound thread message
::  returns the nym that should be the packet sender
::
++  actor-for-thread-msg
  |=  [msg=silk-message thd=silk-thread nyms=(map nym-id pseudonym)]
  ^-  nym-id
  ?+  -.msg  (default-nym nyms)
    %offer          buyer.thd
    %payment-proof  buyer.thd
    %complete       buyer.thd
    %accept         seller.thd
    %reject         seller.thd
    %invoice        seller.thd
    %fulfill        seller.thd
    %dispute        plaintiff.+.msg
    %direct-message  sender.+.msg
  ==
::
::  WS1/WS6: validate that inbound packet sender is allowed for message
::  returns %.y if sender nym matches the expected role for this message
::
++  validate-actor
  |=  [sender=nym-id msg=silk-message thd=(unit silk-thread)]
  ^-  ?
  ?~  thd  %.y  ::  no thread context yet — allow (will be validated on thread creation)
  ?+  -.msg  %.y
    ::  buyer messages: sender must be buyer
    %offer          =(sender buyer.u.thd)
    %payment-proof  =(sender buyer.u.thd)
    %complete       =(sender buyer.u.thd)
    ::  seller messages: sender must be seller
    %accept         =(sender seller.u.thd)
    %reject         ?|  =(sender seller.u.thd)
                        =(sender buyer.u.thd)
                    ==  ::  either party can reject/cancel
    %invoice        =(sender seller.u.thd)
    %fulfill        =(sender seller.u.thd)
    ::  either party can dispute
    %dispute        ?|  =(sender buyer.u.thd)
                        =(sender seller.u.thd)
                    ==
    ::  DMs from stated sender
    %direct-message  =(sender sender.+.msg)
  ==
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
      [%pass /eyre/connect %arvo %e %connect [~ /apps/silk/api] %silk-core]
      ::  subscribe to market and zenith event feeds
      [%pass /market/events %agent [our.bowl %silk-market] %watch /market-events]
      [%pass /zenith/events %agent [our.bowl %silk-zenith] %watch /zenith-events]
      ::  resend timer for pending acks
      [%pass /silk/resend %arvo %b %wait (add now.bowl resend-period)]
      ::  bundle rotation timer
      [%pass /silk/rotate-bundles %arvo %b %wait (add now.bowl ~h12)]
      ::  peer discovery timer: probe skein relays for silk peers
      [%pass /silk/discover-peers %arvo %b %wait (add now.bowl ~m1)]
  ==
::
++  on-save
  !>(state)
::
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  =/  load-result  (mule |.(!<(state-0 old)))
  =.  state  ?:(?=(%& -.load-result) p.load-result *state-0)
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
        ::  subscribe to market and zenith event feeds
        [%pass /market/events %agent [our.bowl %silk-market] %watch /market-events]
        [%pass /zenith/events %agent [our.bowl %silk-zenith] %watch /zenith-events]
        ::  resend timer for pending acks
        [%pass /silk/resend %arvo %b %wait (add now.bowl resend-period)]
        ::  bundle rotation timer
        [%pass /silk/rotate-bundles %arvo %b %wait (add now.bowl ~h12)]
        ::  peer discovery timer
        [%pass /silk/discover-peers %arvo %b %wait (add now.bowl ~m1)]
    ==
  ::  start confirmation polls for released/refunded escrows
  =/  escrow-poll-cards=(list card)
    =/  esc-list  ~(tap by escrow-status.state)
    |-
    ?~  esc-list  ~
    =/  [tid=@uv st=escrow-st]  i.esc-list
    ?.  ?|  =(%released st)
            =(%refunded st)
        ==
      $(esc-list t.esc-list)
    :_  $(esc-list t.esc-list)
    [%pass /escrow-poll/(scot %uv tid) %arvo %b %wait (add now.bowl ~s3)]
  =/  load-cards  :(weld leave-cards load-cards escrow-poll-cards)
  [(weld load-cards (mint-all-nyms-cards our.bowl nyms.state)) this]
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
    ::  escrow broadcast result — start confirmation polling
    ?:  ?=([%escrow-broadcast-ok @ @] raw)
      =/  [* tid=@uv body=@t]  raw
      ~&  [%silk-escrow %broadcast-ok tid]
      ::  start polling multisig balance for confirmation
      =/  esc=(unit escrow-config)  (~(get by escrows.state) tid)
      ?~  esc  `this
      ?:  =('' multisig-address.u.esc)  `this
      =/  poll-card=card
        [%pass /escrow-poll/(scot %uv tid) %arvo %b %wait (add now.bowl ~s5)]
      :-  [poll-card]~
      this
    ?:  ?=([%escrow-broadcast-fail @] raw)
      =/  [* tid=@uv]  raw
      ~&  [%silk-escrow %broadcast-fail tid]
      `this
    ::  channel peer notifications from skein
    ?:  ?=([%channel-join @ @] raw)
      =/  [* channel=@tas ship=@p]  raw
      ?:  =(ship our.bowl)  `this
      ?:  (~(has in peers.state) ship)  `this
      ~&  [%silk-channel %peer-join channel ship]
      =.  peers.state  (~(put in peers.state) ship)
      ~&  [%silk-channel %peer-saved ship %total ~(wyt in peers.state)]
      =/  our-listings=(list listing)  ~(val by listings.state)
      =/  our-contacts=(list nym-contact)
        %+  murn  ~(val by nyms.state)
        |=  n=pseudonym
        =/  bundle  (~(get by our-bundles.state) id.n)
        ?~  bundle  ~
        `[id.n u.bundle]
      =/  mod-cards=(list card)
        %+  turn  ~(val by moderators.state)
        |=(mp=moderator-profile (gossip-card our.bowl ship (~(get by our-bundles.state) (default-nym nyms.state)) (default-nym nyms.state) keys.state [%moderator-profile mp]))
      :_  this
      ;:  weld
        [(event-card [%peer-added ship])]~
        [(gossip-card our.bowl ship (~(get by our-bundles.state) (default-nym nyms.state)) (default-nym nyms.state) keys.state [%catalog our-listings our-contacts])]~
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
      =/  our-contacts=(list nym-contact)
        %+  murn  ~(val by nyms.state)
        |=  n=pseudonym
        =/  bundle  (~(get by our-bundles.state) id.n)
        ?~  bundle  ~
        `[id.n u.bundle]
      =/  catalog-cards=(list card)
        (turn new-peers |=(p=@p (gossip-card our.bowl p (~(get by our-bundles.state) (default-nym nyms.state)) (default-nym nyms.state) keys.state [%catalog our-listings our-contacts])))
      =/  mod-cards=(list card)
        %-  zing
        %+  turn  new-peers
        |=  p=@p
        %+  turn  ~(val by moderators.state)
        |=(mp=moderator-profile (gossip-card our.bowl p (~(get by our-bundles.state) (default-nym nyms.state)) (default-nym nyms.state) keys.state [%moderator-profile mp]))
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
    =/  cued  (cue raw)
    ::  try silk-packet first (signed + reply material)
    =/  pkt-try  (mule |.((silk-packet cued)))
    =/  parsed=(unit [sender=(unit nym-id) reply=(unit @ux) msg=silk-message])
      ?:  ?=(%& -.pkt-try)
        =/  pkt  p.pkt-try
        ::  WS6: look up sender pubkey from known-keys (nym-intro verified)
        ::  or fall back to local nyms
        =/  sender-pub=(unit @ux)
          =/  known  (~(get by known-keys.state) sender.pkt)
          ?^  known  known
          =/  nym-from-local  (~(get by nyms.state) sender.pkt)
          ?~  nym-from-local  ~
          `pubkey.u.nym-from-local
        ::  WS6: verify signature — reject unknown and unsigned senders
        =/  sig-ok=?
          ?~  sender-pub
            ::  WS4: unknown key — reject (must receive nym-intro first)
            ~&  [%silk-core %unknown-sender-rejected sender.pkt]
            %.n
          ?:  =(0x0 sig.pkt)
            ::  WS6: reject unsigned packets from senders with known keys
            ~&  [%silk-core %unsigned-rejected-known-sender sender.pkt]
            %.n
          (veri:ed:crypto sig.pkt (jam body.pkt) u.sender-pub)
        ?.  sig-ok
          ~&  [%silk-core %sig-verify-failed sender.pkt]
          ~
        `[`sender.pkt reply.pkt body.pkt]
      ::  no fallback: unsigned messages are rejected
      ~&  [%silk-core %unsigned-payload-dropped]
      ~
    ?~  parsed
      ~&  [%silk-core %noun-parse-fail]
      `this
    =/  msg=silk-message  msg.u.parsed
    ::  update contact for sender nym from reply material
    =?  contacts.state  ?&(?=(^ reply.u.parsed) ?=(^ sender.u.parsed))
      (~(put by contacts.state) u.sender.u.parsed u.reply.u.parsed)
    ::  gossip messages
    ?:  ?=(%listing -.msg)
      ~&  [%silk-gossip %listing-received id.+.msg]
      ?:  (~(has by listings.state) id.+.msg)  `this
      =.  listings.state  (~(put by listings.state) id.+.msg +.msg)
      :-  [(event-card [%listing-posted +.msg])]~
      this
    ?:  ?=(%catalog-request -.msg)
      ::  WS2: contact-first catalog sync — reply via contact bundle, not ship
      =/  reply-bundle=@ux  reply-contact.msg
      ~&  [%silk-gossip %catalog-request-received request-id.msg]
      =/  our-listings=(list listing)  ~(val by listings.state)
      =/  our-contacts=(list nym-contact)
        %+  murn  ~(val by nyms.state)
        |=  n=pseudonym
        =/  bundle  (~(get by our-bundles.state) id.n)
        ?~  bundle  ~
        `[id.n u.bundle]
      ~&  [%silk-gossip %sending-catalog (lent our-listings) %listings-via-contact]
      =/  dn=nym-id  (default-nym nyms.state)
      =/  catalog-card=card
        (skein-send-card our.bowl reply-bundle (~(get by our-bundles.state) dn) dn keys.state [%catalog our-listings our-contacts])
      ::  send nym-intros for all our nyms alongside catalog
      =/  intro-cards=(list card)
        %+  murn  ~(val by nyms.state)
        |=  n=pseudonym
        =/  kp=(unit nym-keypair)  (~(get by keys.state) id.n)
        ?~  kp  ~
        =/  bundle=(unit @ux)  (~(get by our-bundles.state) id.n)
        ?~  bundle  ~
        ::  WS2: include monotonic seq for rotation tracking
        =/  seq=@ud  +((~(gut by nym-intro-seqs.state) id.n 0))
        =/  intro-msg=@  (jam [%nym-intro id.n pub.u.kp u.bundle seq])
        =/  intro-sig=@ux  (sign:ed:crypto intro-msg sec.u.kp)
        `(skein-send-card our.bowl reply-bundle (~(get by our-bundles.state) id.n) id.n keys.state [%nym-intro id.n pub.u.kp u.bundle intro-sig seq])
      =/  mod-cards=(list card)
        %+  turn  ~(val by moderators.state)
        |=(mp=moderator-profile (skein-send-card our.bowl reply-bundle (~(get by our-bundles.state) dn) dn keys.state [%moderator-profile mp]))
      :_  this
      ;:(weld [catalog-card]~ intro-cards mod-cards)
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
      =.  contacts.state
        =/  cts=(list nym-contact)  contacts.msg
        |-
        ?~  cts  contacts.state
        $(cts t.cts, contacts.state (~(put by contacts.state) nym-id.i.cts contact.i.cts))
      ~&  [%silk-gossip %catalog-received (lent listings.msg) %listings (lent contacts.msg) %contacts]
      :-  [(event-card [%catalog-received (lent listings.msg)])]~
      this
    ::  non-thread messages
    ?:  ?=(%attest -.msg)
      =/  att=attestation  +.msg
      ::  WS6: verify signature — check known-keys first, then local keys
      =/  issuer-pub=(unit @ux)
        =/  known  (~(get by known-keys.state) issuer.att)
        ?^  known  known
        =/  kp  (~(get by keys.state) issuer.att)
        ?~  kp  ~
        `pub.u.kp
      ::  WS6: reject unsigned attestations unconditionally
      ?:  =(0x0 sig.att)
        ~&  [%silk-attest %unsigned-rejected id.att issuer.att]
        `this
      =/  sig-valid=?
        ?~  issuer-pub
          ::  WS4: unknown issuer — reject (must receive nym-intro first)
          ~&  [%silk-attest %unknown-issuer-rejected issuer.att]
          %.n
        =/  att-msg=@  (jam [id.att subject.att issuer.att kind.att score.att note.att issued-at.att])
        (veri:ed:crypto sig.att att-msg u.issuer-pub)
      ?.  sig-valid
        ~&  [%silk-attest %signature-invalid id.att issuer.att]
        `this
      ~&  [%silk-attest %verified-import id.att issuer.att]
      =.  attestations.state  (~(put by attestations.state) id.att att)
      :_  this
      :~  [%pass /silk/rep %agent [our.bowl %silk-rep] %poke %noun !>([%import att])]
          (event-card [%attestation-received att])
      ==
    ::  WS4: inbound evidence for dispute
    ?:  ?=(%evidence -.msg)
      =/  ev=evidence  evidence.msg
      ~&  [%silk-evidence %received id.ev %thread thread-id.ev]
      =.  evidence-store.state  (~(put by evidence-store.state) id.ev ev)
      :-  [(event-card [%evidence-submitted ev])]~
      this
    ?:  ?=(%listing-retracted -.msg)
      ~&  [%silk-gossip %listing-retracted id.+.msg]
      =.  listings.state  (~(del by listings.state) id.+.msg)
      :-  [(event-card [%listing-retracted id.+.msg])]~
      this
    ::  WS2/WS6: signed nym introduction — trust bootstrap with rotation
    ?:  ?=(%nym-intro -.msg)
      =/  nid=nym-id  nym-id.msg
      =/  pub=@ux  pubkey.msg
      =/  intro-sig=@ux  sig.msg
      =/  remote-seq=@ud  seq.msg
      ::  WS6: reject unsigned introductions
      ?:  =(0x0 intro-sig)
        ~&  [%silk-core %nym-intro-unsigned-rejected nid]
        `this
      ::  WS2: reject stale introductions (seq must be > stored)
      =/  stored-seq=@ud  (~(gut by nym-intro-seqs.state) nid 0)
      ?:  (lth remote-seq stored-seq)
        ~&  [%silk-core %nym-intro-stale-rejected nid %got remote-seq %have stored-seq]
        `this
      ::  verify: sig must be ed25519 of (jam [%nym-intro nym-id pubkey contact seq])
      =/  intro-msg=@  (jam [%nym-intro nid pub contact.msg remote-seq])
      ?.  (veri:ed:crypto intro-sig intro-msg pub)
        ~&  [%silk-core %nym-intro-sig-invalid nid]
        `this
      ::  store verified pubkey in known-keys + update seq
      ~&  [%silk-core %nym-intro-verified nid %seq remote-seq]
      =.  known-keys.state  (~(put by known-keys.state) nid pub)
      =.  nym-intro-seqs.state  (~(put by nym-intro-seqs.state) nid remote-seq)
      ::  store contact material
      =.  contacts.state  (~(put by contacts.state) nid contact.msg)
      `this
    ::  WS2: moderator identity introduction
    ?:  ?=(%moderator-intro -.msg)
      =/  mid=moderator-id  moderator-id.msg
      =/  mnid=nym-id  nym-id.msg
      =/  mpub=@ux  pubkey.msg
      =/  msig=@ux  sig.msg
      =/  mcontact=@ux  contact.msg
      ::  reject unsigned
      ?:  =(0x0 msig)
        ~&  [%silk-core %moderator-intro-unsigned-rejected mid]
        `this
      ::  verify: sig must be ed25519 of (jam [%moderator-intro mid mnid mpub mcontact])
      =/  intro-msg=@  (jam [%moderator-intro mid mnid mpub mcontact])
      ?.  (veri:ed:crypto msig intro-msg mpub)
        ~&  [%silk-core %moderator-intro-sig-invalid mid]
        `this
      ::  store contact for the moderator's nym
      ~&  [%silk-core %moderator-intro-verified mid mnid]
      =.  contacts.state  (~(put by contacts.state) mnid mcontact)
      =.  known-keys.state  (~(put by known-keys.state) mnid mpub)
      ::  WS2: flush any pending deliveries for this moderator
      =/  pending=(list [tid=thread-id pmd=pending-mod-delivery])
        %+  murn  ~(tap by awaiting-mod-contact.state)
        |=  [tid=thread-id pmd=pending-mod-delivery]
        ?.  =(mod-id.pmd mid)  ~
        `[tid pmd]
      =/  flush-cards=(list card)
        %+  murn  pending
        |=  [tid=thread-id pmd=pending-mod-delivery]
        ::  WS2: use stored actor — fail closed if no bundle (no buyer fallback)
        =/  act=nym-id  actor.pmd
        =/  bundle=(unit @ux)  (~(get by our-bundles.state) act)
        ?~  bundle
          ~&  [%silk-core %mod-flush-no-actor-bundle act %keeping-queued]
          ~
        `(skein-send-card our.bowl mcontact bundle act keys.state msg.pmd)
      ::  clear only actually flushed entries (not those kept queued)
      =/  flushed-tids=(list thread-id)
        %+  murn  pending
        |=  [tid=thread-id pmd=pending-mod-delivery]
        =/  act=nym-id  actor.pmd
        =/  bundle=(unit @ux)  (~(get by our-bundles.state) act)
        ?~  bundle  ~
        `tid
      =.  awaiting-mod-contact.state
        =/  aw  awaiting-mod-contact.state
        =/  pl  flushed-tids
        |-
        ?~  pl  aw
        $(pl t.pl, aw (~(del by aw) i.pl))
      ~&  [%silk-core %moderator-intro-flushed (lent flush-cards) %pending-deliveries]
      [flush-cards this]
    ::  moderator gossip
    ?:  ?=(%moderator-profile -.msg)
      =/  mp=moderator-profile  +.msg
      ?:  (~(has by moderators.state) id.mp)  `this
      ::  WS4: reject unsigned moderator profiles
      ?:  =(0x0 stake-sig.mp)
        ~&  [%silk-core %unsigned-moderator-rejected id.mp]
        `this
      ::  WS4: verify stake-sig is ECDSA of moderator-id by pubkey
      ::  sig format: (cat 8 s r); recover with both v=0 and v=1
      =/  msg-hash=@  (swp 3 (shax (jam id.mp)))
      =/  sig-r=@  (rsh [3 32] stake-sig.mp)
      =/  sig-s=@  (end [3 32] stake-sig.mp)
      =/  sig-ok=?
        =+  secp256k1:secp:crypto
        =/  try-0  (mule |.((compress-point (ecdsa-raw-recover msg-hash 0 sig-r sig-s))))
        =/  try-1  (mule |.((compress-point (ecdsa-raw-recover msg-hash 1 sig-r sig-s))))
        ?|  ?&(?=(%& -.try-0) =(p.try-0 pubkey.mp))
            ?&(?=(%& -.try-1) =(p.try-1 pubkey.mp))
        ==
      ?.  sig-ok
        ~&  [%silk-core %moderator-sig-invalid id.mp]
        `this
      =.  moderators.state  (~(put by moderators.state) id.mp mp)
      ::  re-send escrow-notify for any escrows with this moderator
      ::  (catches up moderators who joined/rejoined after escrow was agreed)
      ::  Fix 6: direct-only delivery to moderator, no gossip; stripped wallet data
      =/  resend-cards=(list card)
        %-  zing
        %+  murn  ~(tap by escrows.state)
        |=  [tid=@uv esc=escrow-config]
        ?.  =(moderator-id.esc id.mp)  ~
        =/  thd=(unit silk-thread)  (~(get by threads.state) tid)
        ?~  thd  ~
        =/  notify=silk-message  [%escrow-notify (escrow-notify-from-config esc) buyer.u.thd seller.u.thd]
        =/  mod-contact=(unit @ux)  (~(get by contacts.state) nym-id.mp)
        ?~  mod-contact  ~
        ::  WS1: use buyer nym as actor for escrow-notify
        `[(skein-send-card our.bowl u.mod-contact (~(get by our-bundles.state) buyer.u.thd) buyer.u.thd keys.state notify)]~
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
        [(market-advance-card our.bowl (sham [tid %escrow-proposed now.bowl]) tid %escrow-proposed)]~
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
        [(market-advance-card our.bowl (sham [tid %escrow-agreed now.bowl]) tid %escrow-agreed)]~
      ::  Fix 6: buyer notifies moderator directly only, stripped wallet data
      ::  WS2: queue for later if moderator contact missing
      =/  thd-for-notify=(unit silk-thread)  (~(get by threads.state) tid)
      =/  notify-msg=(unit silk-message)
        ?~  thd-for-notify  ~
        `[%escrow-notify (escrow-notify-from-config updated) buyer.u.thd-for-notify seller.u.thd-for-notify]
      =/  mod-for-notify=(unit moderator-profile)  (~(get by moderators.state) moderator-id.updated)
      =/  mod-contact-notify=(unit @ux)  ?~(mod-for-notify ~ (~(get by contacts.state) nym-id.u.mod-for-notify))
      ::  WS2: store with buyer as actor (buyer proposed escrow)
      =?  awaiting-mod-contact.state  ?&(?=(^ notify-msg) ?=(~ mod-contact-notify))
        =/  act=nym-id  ?~(thd-for-notify *nym-id buyer.u.thd-for-notify)
        (~(put by awaiting-mod-contact.state) tid [moderator-id.updated act u.notify-msg])
      =/  notify-cards=(list card)
        ?~  thd-for-notify  ~
        ?~  notify-msg  ~
        ?~  mod-contact-notify  ~
        [(skein-send-card our.bowl u.mod-contact-notify (~(get by our-bundles.state) buyer.u.thd-for-notify) buyer.u.thd-for-notify keys.state u.notify-msg)]~
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
        =/  mod-fee=@ud  (div (mul amount.u.esc-for-sign moderator-fee-bps.u.esc-for-sign) 10.000)
        =/  send-amt=@ud  (sub amount.u.esc-for-sign mod-fee)
        =/  sign-doc=@t
          %:  amino-json-sign-doc-send:multisig
            multisig-address.u.esc-for-sign  to-addr
            send-amt  '$sZ'
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
      =/  mod-fee=@ud  (div (mul amount.u.esc moderator-fee-bps.u.esc) 10.000)
      =/  send-amt=@ud  (sub amount.u.esc mod-fee)
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
          send-amt  '$sZ'
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
        (turn notify-peers |=(p=@p (gossip-card our.bowl p (~(get by our-bundles.state) (default-nym nyms.state)) (default-nym nyms.state) keys.state [%escrow-assembled tid %released tx-hex])))
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
        (turn notify-peers |=(p=@p (gossip-card our.bowl p (~(get by our-bundles.state) (default-nym nyms.state)) (default-nym nyms.state) keys.state [%escrow-assembled tid %refunded tx-hex])))
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
    ::  escrow-notify — only process if we're the moderator
    ::  Fix 6: receives escrow-notify-data (no wallet addresses)
    ?:  ?=(%escrow-notify -.msg)
      =/  end=escrow-notify-data  escrow-notify-data.msg
      ::  accept if we hold the moderator's private key (definitive ownership proof)
      =/  has-key=?  (~(has by mod-keys.state) moderator-id.end)
      ~&  [%silk-escrow %notify-received %mod-id moderator-id.end %has-key has-key]
      ?.  has-key
        ~&  [%silk-escrow %notify-ignored %no-mod-key moderator-id.end]
        `this
      ::  reconstruct partial escrow-config with empty wallets
      =/  esc=escrow-config
        :*  thread-id.end
            buyer-pubkey.end
            seller-pubkey.end
            moderator-pubkey.end
            moderator-id.end
            multisig-address.end
            amount.end
            currency.end
            timeout.end
            moderator-fee-bps.end
            0  0  ''  ''  ::  account-number, sequence, buyer-wallet, seller-wallet
        ==
      =.  escrows.state  (~(put by escrows.state) thread-id.end esc)
      =.  escrow-status.state  (~(put by escrow-status.state) thread-id.end %agreed)
      ::  create stub thread so /my-escrows can show buyer/seller
      =/  stub=silk-thread
        [thread-id.end *listing-id buyer.msg seller.msg %accepted ~ 0x0 now.bowl now.bowl]
      =.  threads.state  (~(put by threads.state) thread-id.end stub)
      ~&  [%silk-moderator %escrow-assigned thread-id.end]
      :-  [(event-card [%escrow-agreed thread-id.end multisig-address.end])]~
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
    ::  thread sync: respond with signed deltas (not full thread)
    ?:  ?=(%sync-thread -.msg)
      =/  our-thd=(unit silk-thread)  (~(get by threads.state) thread-id.msg)
      ?~  our-thd  `this
      ?.  !=(chain.msg chain.u.our-thd)  `this
      ::  chain mismatch — send signed deltas from our thread
      =/  our-nym=nym-id
        ?:  (~(has by nyms.state) seller.u.our-thd)  seller.u.our-thd
        buyer.u.our-thd
      =/  peer-nym=nym-id
        ?:  =(our-nym seller.u.our-thd)  buyer.u.our-thd
        seller.u.our-thd
      =/  contact=(unit @ux)  (~(get by contacts.state) peer-nym)
      ?~  contact  `this
      ::  build signed deltas from our messages
      =/  deltas=(list sync-delta)
        %+  turn  (flop messages.u.our-thd)
        |=  m=silk-message
        =/  delta-sender=nym-id  (actor-for-thread-msg m u.our-thd nyms.state)
        =/  delta-sig=@ux
          =/  kp=(unit nym-keypair)  (~(get by keys.state) delta-sender)
          ?~  kp  0x0
          (sign:ed:crypto (jam m) sec.u.kp)
        [delta-sender delta-sig m `@ux`(sham m)]
      :_  this
      [(skein-send-card our.bowl u.contact (~(get by our-bundles.state) our-nym) our-nym keys.state [%sync-thread-delta thread-id.msg deltas])]~
    ::  WS3: %sync-thread-response removed — unsigned snapshots rejected
    ?:  ?=(%sync-thread-response -.msg)
      ~&  [%silk-sync %sync-thread-response-rejected %unsigned-snapshot]
      `this
    ::  WS3: sender-aware sync deltas — validate each delta with actual sender
    ?:  ?=(%sync-thread-delta -.msg)
      =/  sync-tid=@uv  thread-id.msg
      =/  our-thd=(unit silk-thread)  (~(get by threads.state) sync-tid)
      ?~  our-thd
        ~&  [%silk-sync %delta-no-thread sync-tid]
        `this
      =/  dts=(list sync-delta)  deltas.msg
      =/  acc-thd=silk-thread  u.our-thd
      =/  imported=@ud  0
      |-
      ?~  dts
        ?:  =(0 imported)  `this
        =.  threads.state  (~(put by threads.state) sync-tid acc-thd)
        :-  [(event-card [%thread-updated sync-tid thread-status.acc-thd])]~
        this
      =/  dt=sync-delta  i.dts
      ::  WS3: verify signature against sender's known key
      =/  sender-pub=(unit @ux)  (~(get by known-keys.state) sender.dt)
      ?~  sender-pub
        ~&  [%silk-sync %delta-unknown-sender sync-tid sender.dt]
        $(dts t.dts)
      ?:  =(0x0 sig.dt)
        ~&  [%silk-sync %delta-unsigned-rejected sync-tid sender.dt]
        $(dts t.dts)
      ?.  (veri:ed:crypto sig.dt (jam msg.dt) u.sender-pub)
        ~&  [%silk-sync %delta-sig-invalid sync-tid sender.dt]
        $(dts t.dts)
      ::  WS3: validate sender against actual sender field
      ?.  (validate-actor sender.dt msg.dt `acc-thd)
        ~&  [%silk-sync %delta-actor-invalid sync-tid sender.dt -.msg.dt]
        $(dts t.dts)
      ::  WS3: idempotence check per delta
      ?:  (~(has in processed-msg-ids.state) msg-id.dt)
        ~&  [%silk-sync %delta-idempotent-skip sync-tid msg-id.dt]
        $(dts t.dts)
      ::  WS3: chain continuity check
      =/  nc=@ux  (advance-chain chain.acc-thd `@tas`-.msg.dt)
      =/  new-status=thread-status
        ?:  ?=(%accept -.msg.dt)         %accepted
        ?:  ?=(%reject -.msg.dt)         %cancelled
        ?:  ?=(%payment-proof -.msg.dt)  %paid
        ?:  ?=(%fulfill -.msg.dt)        %fulfilled
        ?:  ?=(%complete -.msg.dt)       %completed
        ?:  ?=(%dispute -.msg.dt)        %disputed
        ?:  ?=(%verdict -.msg.dt)        %resolved
        thread-status.acc-thd
      =.  processed-msg-ids.state  (~(put in processed-msg-ids.state) msg-id.dt)
      $(dts t.dts, imported +(imported), acc-thd acc-thd(thread-status new-status, messages [msg.dt messages.acc-thd], chain nc, updated-at now.bowl))
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
        ::  WS4: reject offers from unknown senders (no verified nym-intro)
        ?:  ?=(~ sender.u.parsed)
          ~&  [%silk-core %offer-no-sender-rejected]
          `this
        ?.  (~(has by known-keys.state) u.sender.u.parsed)
          ~&  [%silk-core %offer-unknown-sender-rejected u.sender.u.parsed]
          `this
        =/  o=offer  +.msg
        =/  init-chain=@ux  (advance-chain `@ux`0 %offer)
        =/  new-thd=silk-thread
          [tid listing-id.o buyer.o seller.o %open [[%offer o] ~] init-chain now.bowl now.bowl]
        ::  WS1: stage — do NOT commit thread yet
        =/  contact=(unit @ux)  (~(get by contacts.state) buyer.o)
        =/  ack-cards=(list card)
          ?~  contact  ~
          [(skein-send-card our.bowl u.contact (~(get by our-bundles.state) seller.o) seller.o keys.state [%ack tid `@ux`(sham msg) now.bowl])]~
        =/  ev-cards=(list card)
          :~  (event-card [%thread-opened new-thd])
              (event-card [%message-received tid msg])
          ==
        ::  WS1: stage proposal for market approval
        =/  [pid=@uv new-proposals=(map @uv pending-proposal) proposal-cards=(list card)]
          %:  stage-proposal
            our.bowl  now.bowl  tid  new-thd  ack-cards  ev-cards  seller.o
            pending-proposals.state  ~  ~  ~  ~  ~
            |=(p=@uv (market-create-card our.bowl p tid listing-id.o buyer.o seller.o id.o amount.o currency.o))
          ==
        =.  pending-proposals.state  new-proposals
        :-  proposal-cards
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
    ::  WS1/WS6: validate actor — reject packets where sender nym
    ::  cannot legally perform the enclosed action
    ?:  ?=(~ sender.u.parsed)
      ~&  [%silk-core %missing-sender-rejected -.msg %thread tid]
      `this
    ?.  (validate-actor u.sender.u.parsed msg thd)
      ~&  [%silk-core %actor-mismatch-rejected -.msg %sender sender.u.parsed %thread tid]
      `this
    ::  WS5: idempotence — skip already-processed side-effecting messages
    =/  mid=@ux  (msg-id msg)
    ?:  (~(has in processed-msg-ids.state) mid)
      ~&  [%silk-core %idempotent-skip tid -.msg]
      `this
    =.  processed-msg-ids.state  (~(put in processed-msg-ids.state) mid)
    ::  WS1: map inbound message to market order-status for propose-advance
    =/  proposed-market-status=@tas
      ?:  ?=(%accept -.msg)         %accepted
      ?:  ?=(%reject -.msg)         %cancelled
      ?:  ?=(%payment-proof -.msg)  %paid
      ?:  ?=(%fulfill -.msg)        %fulfilled
      ?:  ?=(%complete -.msg)       %completed
      ?:  ?=(%dispute -.msg)        %disputed
      ?:  ?=(%verdict -.msg)        %resolved
      %$  ::  no market-relevant status (DM, invoice, etc.)
    ::  update thread status based on inbound message type
    =/  new-status=thread-status
      ?:  ?=(%accept -.msg)         %accepted
      ?:  ?=(%reject -.msg)         %cancelled
      ?:  ?=(%payment-proof -.msg)  %paid
      ?:  ?=(%fulfill -.msg)        %fulfilled
      ?:  ?=(%complete -.msg)       %completed
      ?:  ?=(%dispute -.msg)        %disputed
      ?:  ?=(%verdict -.msg)        %resolved
      thread-status.u.thd
    ::  advance chain hash
    =/  new-chain=@ux  (advance-chain chain.u.thd `@tas`-.msg)
    =/  updated=silk-thread
      u.thd(thread-status new-status, messages [msg messages.u.thd], chain new-chain, updated-at now.bowl)
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
    ::  WS1: we ack as the other party (our role nym)
    =/  our-nym=nym-id
      ?:  =(sender-nym buyer.u.thd)  seller.u.thd
      buyer.u.thd
    =/  contact=(unit @ux)  (~(get by contacts.state) sender-nym)
    =/  ack-cards=(list card)
      ?~  contact  ~
      [(skein-send-card our.bowl u.contact (~(get by our-bundles.state) our-nym) our-nym keys.state [%ack tid `@ux`(sham msg) now.bowl])]~
    ::  WS1: stage via proposal for market-relevant messages
    ::  non-market messages (DM, invoice receipt, etc.) commit immediately
    ?:  =(%$ proposed-market-status)
      ::  no market status involved — commit immediately
      =.  threads.state  (~(put by threads.state) tid updated)
      :-  ;:(weld [(event-card [%message-received tid msg])]~ ack-cards -.auto-release -.auto-refund)
      this
    ::  market-relevant — stage proposal
    =/  ev-cards=(list card)
      ;:(weld [(event-card [%message-received tid msg])]~ -.auto-release -.auto-refund)
    =/  [pid=@uv new-proposals=(map @uv pending-proposal) proposal-cards=(list card)]
      %:  stage-proposal
        our.bowl  now.bowl  tid  updated  ack-cards  ev-cards  our-nym
        pending-proposals.state  ~  ~  ~  ~  ~
        |=(p=@uv (market-advance-card our.bowl p tid proposed-market-status))
      ==
    =.  pending-proposals.state  new-proposals
    :-  proposal-cards
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
      =/  order-threads=(list silk-thread)  ~(val by threads.state)
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
            ?:  ?=(%open thread-status.t)
              'offered'
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
      ::  WS4: scry %zenith directly for wallet accounts
      =/  result
        (mule |.(.^(* %gx /(scot %p our.bowl)/zenith/(scot %da now.bowl)/accounts/noun)))
      ::  fall back to silk-zenith if %zenith not available
      =?  result  ?=(%| -.result)
        (mule |.(.^(* %gx /(scot %p our.bowl)/silk-zenith/(scot %da now.bowl)/accounts/noun)))
      ?:  ?=(%| -.result)
        %-  give-json  :-  eyre-id
        (pairs:enjs:format ~[['accounts' [%a ~]]])
      ::  WS4: try %zenith account type (addr=@t ...) then silk zenith-account (address=@t ...)
      =/  zen-try  (mule |.(;;((map ?(~ @t) [addr=@t pub-key=@ux priv-key=@ux acc-num=@ud seq-num=@ud]) p.result)))
      ?:  ?=(%& -.zen-try)
        =/  entries=(list [?(~ @t) [addr=@t pub-key=@ux priv-key=@ux acc-num=@ud seq-num=@ud]])
          ~(tap by p.zen-try)
        %-  give-json  :-  eyre-id
        %-  pairs:enjs:format
        :~  :-  'accounts'
            :-  %a
            %+  turn  entries
            |=  [name=?(~ @t) acc=[addr=@t pub-key=@ux priv-key=@ux acc-num=@ud seq-num=@ud]]
            (pairs:enjs:format ~[['name' s+?~(name '' name)] ['address' s+addr.acc]])
        ==
      ::  try silk zenith-account format
      =/  acc-try  (mule |.(;;((map @t zenith-account) p.result)))
      ?:  ?=(%| -.acc-try)
        %-  give-json  :-  eyre-id
        (pairs:enjs:format ~[['accounts' [%a ~]]])
      =/  entries=(list [@t zenith-account])  ~(tap by p.acc-try)
      %-  give-json  :-  eyre-id
      %-  pairs:enjs:format
      :~  :-  'accounts'
          :-  %a
          %+  turn  entries
          |=  [name=@t acc=zenith-account]
          (pairs:enjs:format ~[['name' s+name] ['address' s+address.acc]])
      ==
    ::
        [%stats ~]
      %-  give-json  :-  eyre-id
      %-  pairs:enjs:format
      :~  ['nyms' (numb:enjs:format ~(wyt by nyms.state))]
          ['listings' (numb:enjs:format ~(wyt by listings.state))]
          ['threads' (numb:enjs:format ~(wyt by threads.state))]
          ['contacts' (numb:enjs:format ~(wyt by contacts.state))]
          ['peers' (numb:enjs:format ~(wyt in peers.state))]
          ['pendingAcks' (numb:enjs:format ~(wyt by pending-acks.state))]
          ['keys' (numb:enjs:format ~(wyt by keys.state))]
          ['moderators' (numb:enjs:format ~(wyt by moderators.state))]
          ['escrows' (numb:enjs:format ~(wyt by escrows.state))]
          ['bundles' (numb:enjs:format ~(wyt by our-bundles.state))]
          ['knownKeys' (numb:enjs:format ~(wyt by known-keys.state))]
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
    ?:  =(%'submit-evidence' u.typ)
      (handle-api-submit-evidence eyre-id u.jon)
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
    ::  WS4: poke silk-zenith to register the key — on poke-ack we scry the address
    =/  zen-card=card
      [%pass /zenith-addr/(scot %uv tid) %agent [our.bowl %silk-zenith] %poke %noun !>([%add-account acc-name priv-key])]
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
    ::  WS1: do NOT commit thread yet — stage via proposal
    ::  send completion to counterparty over skein
    =/  counter=nym-id  seller.u.thd
    =/  contact=(unit @ux)  (~(get by contacts.state) counter)
    ::  WS1: buyer is the actor for complete
    =/  actor=nym-id  buyer.u.thd
    =/  send-cards=(list card)
      ?~  contact
        ~&  [%silk-warn %no-contact-for-complete counter]
        ~
      [(skein-send-card our.bowl u.contact (~(get by our-bundles.state) actor) actor keys.state complete-msg)]~
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
    =.  this  +.release-result
    ::  WS1: stage proposal — thread committed only on approval
    =/  ev-cards=(list card)
      ;:(weld [(event-card [%thread-updated tid %completed])]~ -.release-result (ok-response eyre-id))
    =/  [pid=@uv new-proposals=(map @uv pending-proposal) proposal-cards=(list card)]
      %:  stage-proposal
        our.bowl  now.bowl  tid  updated  send-cards  ev-cards  actor
        pending-proposals.state  ~  ~  ~  ~  ~
        |=(p=@uv (market-advance-card our.bowl p tid %completed))
      ==
    =.  pending-proposals.state  new-proposals
    :-  proposal-cards
    this
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
    ::  WS1: issuer is the actor for attestation
    =/  contact=(unit @ux)  (~(get by contacts.state) subject)
    =/  send-cards=(list card)
      ?~  contact  ~
      [(skein-send-card our.bowl u.contact (~(get by our-bundles.state) issuer) issuer keys.state [%attest att])]~
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
    ::  store our contact for this sender nym
    =/  sender-bundle  (~(get by our-bundles.state) sender)
    =?  contacts.state  ?=(^ sender-bundle)
      (~(put by contacts.state) sender u.sender-bundle)
    =/  sender-contact=(unit @ux)  (~(get by contacts.state) sender)
    =/  contact=(unit @ux)  (~(get by contacts.state) seller.u.lst)
    ::  WS1: DM sender is the actor
    =/  send-cards=(list card)
      ?~  contact
        ~&  [%silk-warn %no-contact-for-dm seller.u.lst]
        ~
      :~  (skein-send-card our.bowl u.contact (~(get by our-bundles.state) sender) sender keys.state dm)
          ?~  sender-contact
            (skein-send-card our.bowl u.contact (~(get by our-bundles.state) sender) sender keys.state [%catalog ~ ~])
          (skein-send-card our.bowl u.contact (~(get by our-bundles.state) sender) sender keys.state [%catalog ~ [sender u.sender-contact]~])
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
    ::  WS1: reply sender is the actor
    =/  contact=(unit @ux)  (~(get by contacts.state) counter)
    =/  send-cards=(list card)
      ?~  contact  ~
      [(skein-send-card our.bowl u.contact (~(get by our-bundles.state) sender) sender keys.state dm)]~
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
    ::  WS4: poke %silk-zenith to send payment (proper payment authority)
    =/  send-card=card
      [%pass /zenith-pay/(scot %uv tid) %agent [our.bowl %silk-zenith] %poke %noun !>([%send-to-addr acc-name pay-addr amount denom])]
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
    ::  for escrow transactions: check escrow status instead of balance
    =/  esc-st=(unit escrow-st)  (~(get by escrow-status.state) tid)
    ?:  ?&  ?=(^ esc-st)
            ?|  =(%released u.esc-st)
                =(%refunded u.esc-st)
                =(%confirmed u.esc-st)
            ==
        ==
      =/  confirmed=?  =(%confirmed u.esc-st)
      ::  if not confirmed yet, start a poll
      =/  poll-cards=(list card)
        ?:  confirmed  ~
        :~  [%pass /escrow-poll/(scot %uv tid) %arvo %b %wait (add now.bowl ~s3)]
        ==
      =/  resp=json
        %-  pairs:enjs:format
        :~  ['thread_id' s+(scot %uv tid)]
            ['status' s+`@t`thread-status.u.thd]
            ['escrow_status' s+`@t`u.esc-st]
            ['verified' b+confirmed]
            ['escrow' b+%.y]
        ==
      :_  this
      (weld poll-cards (give-json eyre-id resp))
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
    ::  deduct moderator fee on release, full refund on refund
    =/  mod-fee=@ud
      ?:  =('release' act)  (div (mul amount.u.esc moderator-fee-bps.u.esc) 10.000)
      0
    =/  send-amt=@ud  (sub amount.u.esc mod-fee)
    ::  build amino JSON sign doc and sign
    =/  sign-doc=@t
      %:  amino-json-sign-doc-send:multisig
        multisig-address.u.esc  to-addr
        send-amt  '$sZ'
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
      |=(p=@p (gossip-card our.bowl p (~(get by our-bundles.state) (default-nym nyms.state)) (default-nym nyms.state) keys.state esc-msg))
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
  ::  WS4: submit evidence for dispute
  ::
  ++  handle-api-submit-evidence
    |=  [eyre-id=@ta jon=json]
    ^-  (quip card _this)
    =/  [tid-t=@t nt=@t nym-t=@t]
      =,  dejs:format
      ((ot ~['thread_id'^so note+so nym+so]) jon)
    =/  tid=@uv  (slav %uv tid-t)
    =/  author=nym-id  (slav %uv nym-t)
    =/  ev=evidence
      :*  (sham [our.bowl now.bowl tid nt])
          tid
          author
          `@ux`(sham nt)
          nt
          now.bowl
      ==
    =/  result  (handle-command [%submit-evidence ev])
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
      ::  WS6: register our own pubkey in known-keys
      =.  known-keys.state  (~(put by known-keys.state) id pub)
      ::  Fix 2: mint per-nym contact bundle
      :_  this
      :~  (event-card [%nym-created nym])
          (mint-nym-card our.bowl id)
      ==
    ::
        %drop-nym
      =.  nyms.state  (~(del by nyms.state) id.cmd)
      =.  keys.state  (~(del by keys.state) id.cmd)
      =.  contacts.state  (~(del by contacts.state) id.cmd)
      =.  our-bundles.state  (~(del by our-bundles.state) id.cmd)
      :-  [(event-card [%nym-dropped id.cmd])]~
      this
    ::
        %post-listing
      =.  listings.state  (~(put by listings.state) id.listing.cmd listing.cmd)
      ::  broadcast listing + seller contact to all peers via skein
      =/  seller-contact=(unit @ux)  (~(get by our-bundles.state) seller.listing.cmd)
      =/  active-peers=(list @p)
        %+  murn  ~(tap in peers.state)
        |=(p=@p ?:(=(p our.bowl) ~ `p))
      ~&  [%silk-gossip %broadcasting-listing id.listing.cmd %to-peers (lent active-peers)]
      =/  peer-cards=(list card)
        ?~  seller-contact
          (turn active-peers |=(p=@p (gossip-card our.bowl p (~(get by our-bundles.state) (default-nym nyms.state)) (default-nym nyms.state) keys.state [%catalog [listing.cmd]~ ~])))
        =/  nc=nym-contact  [seller.listing.cmd u.seller-contact]
        (turn active-peers |=(p=@p (gossip-card our.bowl p (~(get by our-bundles.state) (default-nym nyms.state)) (default-nym nyms.state) keys.state [%catalog [listing.cmd]~ [nc]~])))
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
        (turn active-peers |=(p=@p (gossip-card our.bowl p (~(get by our-bundles.state) (default-nym nyms.state)) (default-nym nyms.state) keys.state [%listing-retracted id.cmd])))
      :-  (weld [(event-card [%listing-retracted id.cmd])]~ peer-cards)
      this
    ::
        %add-peer
      ?:  =(ship.cmd our.bowl)  `this
      =.  peers.state  (~(put in peers.state) ship.cmd)
      =/  our-listings=(list listing)  ~(val by listings.state)
      =/  our-contacts=(list nym-contact)
        %+  murn  ~(val by nyms.state)
        |=  n=pseudonym
        =/  bundle  (~(get by our-bundles.state) id.n)
        ?~  bundle  ~
        `[id.n u.bundle]
      ~&  [%silk-gossip %add-peer ship.cmd %sending (lent our-listings) %listings]
      ::  WS2: catalog-request now uses request-id + reply-contact
      =/  dn=nym-id  (default-nym nyms.state)
      =/  reply-bundle=(unit @ux)  (~(get by our-bundles.state) dn)
      =/  rid=@uv  (sham [our.bowl now.bowl ship.cmd])
      :_  this
      :~  (event-card [%peer-added ship.cmd])
          (gossip-card our.bowl ship.cmd reply-bundle dn keys.state [%catalog our-listings our-contacts])
          ?~  reply-bundle
            (gossip-card our.bowl ship.cmd ~ dn keys.state [%catalog-request rid 0x0])
          (gossip-card our.bowl ship.cmd reply-bundle dn keys.state [%catalog-request rid u.reply-bundle])
      ==
    ::
        %drop-peer
      =.  peers.state  (~(del in peers.state) ship.cmd)
      :-  [(event-card [%peer-removed ship.cmd])]~
      this
    ::
        %sync-catalog
      ~&  [%silk-sync %peer-count ~(wyt in peers.state) %peers ~(tap in peers.state)]
      ::  WS2: catalog-request now carries request-id + reply-contact
      =/  dn=nym-id  (default-nym nyms.state)
      =/  reply-bundle=(unit @ux)  (~(get by our-bundles.state) dn)
      ?~  reply-bundle
        ~&  [%silk-sync %no-bundle-for-catalog-request]
        `this
      :_  this
      %+  turn  ~(tap in peers.state)
      |=  p=@p
      =/  rid=@uv  (sham [our.bowl now.bowl p])
      (gossip-card our.bowl p reply-bundle dn keys.state [%catalog-request rid u.reply-bundle])
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
      ::  WS1: stage — do NOT commit thread yet
      ::  ensure buyer contact is stored and sent to seller
      =/  buyer-bundle  (~(get by our-bundles.state) buyer.o)
      =?  contacts.state  ?=(^ buyer-bundle)
        (~(put by contacts.state) buyer.o u.buyer-bundle)
      =/  buyer-contact=(unit @ux)  (~(get by contacts.state) buyer.o)
      =/  contact=(unit @ux)  (~(get by contacts.state) seller.o)
      ~&  [%silk-send-offer %contact-found ?=(^ contact) %known-contacts ~(wyt by contacts.state)]
      =/  send-cards=(list card)
        ?~  contact
          ~&  [%silk-warn %no-contact-for-seller seller.o %known ~(key by contacts.state)]
          ~
        ::  WS1: buyer is the actor for offers
        :~  (skein-send-card our.bowl u.contact (~(get by our-bundles.state) buyer.o) buyer.o keys.state [%offer o])
            ?~  buyer-contact
              (skein-send-card our.bowl u.contact (~(get by our-bundles.state) buyer.o) buyer.o keys.state [%catalog ~ ~])
            (skein-send-card our.bowl u.contact (~(get by our-bundles.state) buyer.o) buyer.o keys.state [%catalog ~ [buyer.o u.buyer-contact]~])
        ==
      ::  WS1: stage proposal for market approval
      =/  ev-cards=(list card)  [(event-card [%thread-opened thd])]~
      ::  stage pending-ack instead of committing immediately
      =/  s-pend=(list [@ux pending-msg-entry])
        ?~  contact  ~
        =/  [hash=@ux pm=pending-msg]  (make-pending tid u.contact [%offer o] now.bowl buyer.o)
        ~[[hash [hash tid u.contact [%offer o] now.bowl 0 buyer.o]]]
      =/  [pid=@uv new-proposals=(map @uv pending-proposal) proposal-cards=(list card)]
        %:  stage-proposal
          our.bowl  now.bowl  tid  thd  send-cards  ev-cards  buyer.o
          pending-proposals.state  s-pend  ~  ~  ~  ~
          |=(p=@uv (market-create-card our.bowl p tid listing-id.o buyer.o seller.o id.o amount.o currency.o))
        ==
      =.  pending-proposals.state  new-proposals
      :-  proposal-cards
      this
    ::
        %accept-offer
      =/  thd=(unit silk-thread)  (~(get by threads.state) thread-id.cmd)
      ?~  thd  `this
      ::  WS1: stage — check inventory but do NOT decrement yet
      =/  inv=@ud  (~(gut by inventory.state) listing-id.u.thd 0)
      ?:  ?&((gth inv 0) =(inv 0))  `this  ::  unreachable but safe
      =/  acc=accept  [thread-id.cmd offer-id.cmd now.bowl]
      =/  nc=@ux  (advance-chain chain.u.thd %accept)
      =/  updated=silk-thread
        u.thd(thread-status %accepted, messages [[%accept acc] messages.u.thd], chain nc, updated-at now.bowl)
      ::  send seller contact alongside accept so buyer can reply
      =/  seller-bundle  (~(get by our-bundles.state) seller.u.thd)
      =?  contacts.state  ?=(^ seller-bundle)
        (~(put by contacts.state) seller.u.thd u.seller-bundle)
      =/  seller-contact=(unit @ux)  (~(get by contacts.state) seller.u.thd)
      =/  contact=(unit @ux)  (~(get by contacts.state) buyer.u.thd)
      =/  send-cards=(list card)
        ?~  contact  ~
        :~  (skein-send-card our.bowl u.contact (~(get by our-bundles.state) seller.u.thd) seller.u.thd keys.state [%accept acc])
            ?~  seller-contact
              (skein-send-card our.bowl u.contact (~(get by our-bundles.state) seller.u.thd) seller.u.thd keys.state [%catalog ~ ~])
            (skein-send-card our.bowl u.contact (~(get by our-bundles.state) seller.u.thd) seller.u.thd keys.state [%catalog ~ [seller.u.thd u.seller-contact]~])
        ==
      ::  stage pending-ack and inventory instead of committing immediately
      =/  s-pend=(list [@ux pending-msg-entry])
        ?~  contact  ~
        =/  [hash=@ux pm=pending-msg]  (make-pending thread-id.cmd u.contact [%accept acc] now.bowl seller.u.thd)
        ~[[hash [hash thread-id.cmd u.contact [%accept acc] now.bowl 0 seller.u.thd]]]
      =/  s-inv=(list [listing-id @ud])
        ?:  (gth inv 0)  ~[[listing-id.u.thd (dec inv)]]
        ~
      ::  WS1: stage proposal — thread committed only on approval
      =/  ev-cards=(list card)  [(event-card [%thread-updated thread-id.cmd %accepted])]~
      =/  [pid=@uv new-proposals=(map @uv pending-proposal) proposal-cards=(list card)]
        %:  stage-proposal
          our.bowl  now.bowl  thread-id.cmd  updated  send-cards  ev-cards  seller.u.thd
          pending-proposals.state  s-pend  s-inv  ~  ~  ~
          |=(p=@uv (market-advance-card our.bowl p thread-id.cmd %accepted))
        ==
      =.  pending-proposals.state  new-proposals
      :-  proposal-cards
      this
    ::
        %reject-offer
      =/  thd=(unit silk-thread)  (~(get by threads.state) thread-id.cmd)
      ?~  thd  `this
      =/  rej=reject  [thread-id.cmd offer-id.cmd reason.cmd now.bowl]
      =/  nc=@ux  (advance-chain chain.u.thd %reject)
      =/  updated=silk-thread
        u.thd(thread-status %cancelled, messages [[%reject rej] messages.u.thd], chain nc, updated-at now.bowl)
      =/  contact=(unit @ux)  (~(get by contacts.state) buyer.u.thd)
      =/  send-cards=(list card)
        ?~  contact  ~
        [(skein-send-card our.bowl u.contact (~(get by our-bundles.state) seller.u.thd) seller.u.thd keys.state [%reject rej])]~
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
      ::  WS1: stage proposal — thread committed only on approval
      =/  ev-cards=(list card)
        (weld [(event-card [%thread-updated thread-id.cmd %cancelled])]~ -.refund-result)
      =/  [pid=@uv new-proposals=(map @uv pending-proposal) proposal-cards=(list card)]
        %:  stage-proposal
          our.bowl  now.bowl  thread-id.cmd  updated  send-cards  ev-cards  seller.u.thd
          pending-proposals.state  ~  ~  ~  ~  ~
          |=(p=@uv (market-advance-card our.bowl p thread-id.cmd %cancelled))
        ==
      =.  pending-proposals.state  new-proposals
      :-  proposal-cards
      this
    ::
        %cancel-thread
      =/  thd=(unit silk-thread)  (~(get by threads.state) thread-id.cmd)
      ?~  thd  `this
      ?:  ?=(?(%completed %cancelled %resolved) thread-status.u.thd)  `this
      =/  nc=@ux  (advance-chain chain.u.thd %reject)
      =/  rej=reject  [thread-id.cmd `@uv`0 reason.cmd now.bowl]
      =/  updated=silk-thread
        u.thd(thread-status %cancelled, messages [[%reject rej] messages.u.thd], chain nc, updated-at now.bowl)
      ::  WS1: do NOT commit thread yet — stage via proposal
      ::  notify counterparty
      =/  counterparty=nym-id
        ?:  (~(has by nyms.state) seller.u.thd)  buyer.u.thd
        seller.u.thd
      ::  WS1: canceller is the actor
      =/  canceller=nym-id
        ?:  (~(has by nyms.state) seller.u.thd)  seller.u.thd
        buyer.u.thd
      =/  contact=(unit @ux)  (~(get by contacts.state) counterparty)
      =/  send-cards=(list card)
        ?~  contact  ~
        [(skein-send-card our.bowl u.contact (~(get by our-bundles.state) canceller) canceller keys.state [%reject rej])]~
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
      ::  WS1: stage proposal — thread committed only on approval
      =/  ev-cards=(list card)
        (weld [(event-card [%thread-updated thread-id.cmd %cancelled])]~ -.refund-result)
      ::  stage inventory restore if order was accepted
      =/  s-inv=(list [listing-id @ud])
        ?.  ?=(%accepted thread-status.u.thd)  ~
        =/  inv=@ud  (~(gut by inventory.state) listing-id.u.thd 0)
        ?:(=(inv 0) ~ ~[[listing-id.u.thd +(inv)]])
      =/  [pid=@uv new-proposals=(map @uv pending-proposal) proposal-cards=(list card)]
        %:  stage-proposal
          our.bowl  now.bowl  thread-id.cmd  updated  send-cards  ev-cards  canceller
          pending-proposals.state  ~  s-inv  ~  ~  ~
          |=(p=@uv (market-advance-card our.bowl p thread-id.cmd %cancelled))
        ==
      =.  pending-proposals.state  new-proposals
      :-  proposal-cards
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
      ::  WS1: stage — do NOT commit thread yet
      =/  contact=(unit @ux)  (~(get by contacts.state) buyer.u.thd)
      =/  send-cards=(list card)
        ?~  contact  ~
        [(skein-send-card our.bowl u.contact (~(get by our-bundles.state) seller.u.thd) seller.u.thd keys.state [%invoice inv])]~
      =/  ev-cards=(list card)  [(event-card [%thread-updated thread-id.inv %accepted])]~
      =/  [pid=@uv new-proposals=(map @uv pending-proposal) proposal-cards=(list card)]
        %:  stage-proposal
          our.bowl  now.bowl  thread-id.inv  updated  send-cards  ev-cards  seller.u.thd
          pending-proposals.state  ~  ~  ~  ~  ~
          |=(p=@uv (market-advance-card our.bowl p thread-id.inv %invoiced))
        ==
      =.  pending-proposals.state  new-proposals
      :-  proposal-cards
      this
    ::
        %submit-payment
      =/  thd=(unit silk-thread)  (~(get by threads.state) thread-id.payment-proof.cmd)
      ?~  thd  `this
      =/  pp=payment-proof  payment-proof.cmd
      =/  nc=@ux  (advance-chain chain.u.thd %payment-proof)
      =/  updated=silk-thread
        u.thd(thread-status %paid, messages [[%payment-proof pp] messages.u.thd], chain nc, updated-at now.bowl)
      ::  WS1: stage — do NOT commit thread yet
      =/  contact=(unit @ux)  (~(get by contacts.state) seller.u.thd)
      =/  send-cards=(list card)
        ?~  contact  ~
        [(skein-send-card our.bowl u.contact (~(get by our-bundles.state) buyer.u.thd) buyer.u.thd keys.state [%payment-proof pp])]~
      ::  stage pending-ack
      =/  s-pend=(list [@ux pending-msg-entry])
        ?~  contact  ~
        =/  [hash=@ux pm=pending-msg]  (make-pending thread-id.pp u.contact [%payment-proof pp] now.bowl buyer.u.thd)
        ~[[hash [hash thread-id.pp u.contact [%payment-proof pp] now.bowl 0 buyer.u.thd]]]
      ::  stage escrow-status fund if active
      =/  has-esc-fund=?
        ?&  (~(has by escrows.state) thread-id.pp)
            ?=(^ (~(get by escrow-status.state) thread-id.pp))
            ?=(%agreed (need (~(get by escrow-status.state) thread-id.pp)))
        ==
      =/  s-esc-st=(list [@uv escrow-st])
        ?.  has-esc-fund  ~
        ~&  [%silk-escrow %staging-fund-on-payment thread-id.pp]
        ~[[thread-id.pp %funded]]
      =/  fund-cards=(list card)
        ?.  has-esc-fund  ~
        =/  fund-pid=@uv  (sham [thread-id.pp %escrowed now.bowl])
        [(market-advance-card our.bowl fund-pid thread-id.pp %escrowed)]~
      =/  query-cards=(list card)
        ?.  has-esc-fund  ~
        =/  esc=(unit escrow-config)  (~(get by escrows.state) thread-id.pp)
        ?~  esc  ~
        ?:  =('' multisig-address.u.esc)  ~
        :~  [%pass /zenith/query-account %agent [our.bowl %silk-zenith] %poke %noun !>([%query-escrow-account thread-id.pp multisig-address.u.esc])]
        ==
      =/  ev-cards=(list card)  ;:(weld [(event-card [%thread-updated thread-id.pp %paid])]~ fund-cards query-cards)
      =/  [pid=@uv new-proposals=(map @uv pending-proposal) proposal-cards=(list card)]
        %:  stage-proposal
          our.bowl  now.bowl  thread-id.pp  updated  send-cards  ev-cards  buyer.u.thd
          pending-proposals.state  s-pend  ~  s-esc-st  ~  ~
          |=(p=@uv (market-advance-card our.bowl p thread-id.pp %paid))
        ==
      =.  pending-proposals.state  new-proposals
      :-  proposal-cards
      this
    ::
        %send-fulfillment
      =/  thd=(unit silk-thread)  (~(get by threads.state) thread-id.fulfillment.cmd)
      ?~  thd  `this
      =/  ful=fulfillment  fulfillment.cmd
      =/  nc=@ux  (advance-chain chain.u.thd %fulfill)
      =/  updated=silk-thread
        u.thd(thread-status %fulfilled, messages [[%fulfill ful] messages.u.thd], chain nc, updated-at now.bowl)
      ::  WS1: stage — do NOT commit thread yet
      =/  contact=(unit @ux)  (~(get by contacts.state) buyer.u.thd)
      =/  send-cards=(list card)
        ?~  contact  ~
        [(skein-send-card our.bowl u.contact (~(get by our-bundles.state) seller.u.thd) seller.u.thd keys.state [%fulfill ful])]~
      =/  s-pend=(list [@ux pending-msg-entry])
        ?~  contact  ~
        =/  [hash=@ux pm=pending-msg]  (make-pending thread-id.ful u.contact [%fulfill ful] now.bowl seller.u.thd)
        ~[[hash [hash thread-id.ful u.contact [%fulfill ful] now.bowl 0 seller.u.thd]]]
      =/  ev-cards=(list card)  [(event-card [%thread-updated thread-id.ful %fulfilled])]~
      =/  [pid=@uv new-proposals=(map @uv pending-proposal) proposal-cards=(list card)]
        %:  stage-proposal
          our.bowl  now.bowl  thread-id.ful  updated  send-cards  ev-cards  seller.u.thd
          pending-proposals.state  s-pend  ~  ~  ~  ~
          |=(p=@uv (market-advance-card our.bowl p thread-id.ful %fulfilled))
        ==
      =.  pending-proposals.state  new-proposals
      :-  proposal-cards
      this
    ::
        %file-dispute
      =/  thd=(unit silk-thread)  (~(get by threads.state) thread-id.dispute.cmd)
      ?~  thd  `this
      =/  dis=dispute  dispute.cmd
      =/  nc=@ux  (advance-chain chain.u.thd %dispute)
      =/  updated=silk-thread
        u.thd(thread-status %disputed, messages [[%dispute dis] messages.u.thd], chain nc, updated-at now.bowl)
      ::  WS1: stage — do NOT commit thread yet
      =/  counter=nym-id
        ?:  =(plaintiff.dis buyer.u.thd)
          seller.u.thd
        buyer.u.thd
      =/  contact=(unit @ux)  (~(get by contacts.state) counter)
      =/  send-cards=(list card)
        ?~  contact  ~
        [(skein-send-card our.bowl u.contact (~(get by our-bundles.state) plaintiff.dis) plaintiff.dis keys.state [%dispute dis])]~
      ::  send dispute directly to moderator via contact
      =/  esc-for-dis=(unit escrow-config)  (~(get by escrows.state) thread-id.dis)
      =/  mod-cards=(list card)
        ?~  esc-for-dis  ~
        =/  dispute-msg=silk-message  [%escrow-dispute thread-id.dis dis]
        =/  mod=(unit moderator-profile)  (~(get by moderators.state) moderator-id.u.esc-for-dis)
        =/  mod-contact=(unit @ux)
          ?~(mod ~ (~(get by contacts.state) nym-id.u.mod))
        ?~  mod-contact
          ::  WS2: store in awaiting-mod-contact with correct actor
          ~&  [%silk-escrow %dispute-queued-no-contact moderator-id.u.esc-for-dis]
          =.  awaiting-mod-contact.state
            (~(put by awaiting-mod-contact.state) thread-id.dis [moderator-id.u.esc-for-dis plaintiff.dis dispute-msg])
          ~
        ~&  [%silk-escrow %dispute-to-moderator %direct-only moderator-id.u.esc-for-dis]
        [(skein-send-card our.bowl u.mod-contact (~(get by our-bundles.state) plaintiff.dis) plaintiff.dis keys.state dispute-msg)]~
      =/  ev-cards=(list card)  [(event-card [%thread-updated thread-id.dis %disputed])]~
      =/  extra-send=(list card)  (weld send-cards mod-cards)
      =/  [pid=@uv new-proposals=(map @uv pending-proposal) proposal-cards=(list card)]
        %:  stage-proposal
          our.bowl  now.bowl  thread-id.dis  updated  extra-send  ev-cards  plaintiff.dis
          pending-proposals.state  ~  ~  ~  ~  ~
          |=(p=@uv (market-advance-card our.bowl p thread-id.dis %disputed))
        ==
      =.  pending-proposals.state  new-proposals
      :-  proposal-cards
      this
    ::
    ::  WS4: submit evidence for a dispute
    ::
        %submit-evidence
      =/  ev=evidence  evidence.cmd
      =/  thd=(unit silk-thread)  (~(get by threads.state) thread-id.ev)
      ?~  thd  `this
      ::  only allow evidence on disputed threads
      ?.  =(%disputed thread-status.u.thd)
        ~&  [%silk-evidence %thread-not-disputed thread-id.ev]
        `this
      =.  evidence-store.state  (~(put by evidence-store.state) id.ev ev)
      ::  send evidence to counterparty
      =/  counter=nym-id
        ?:  =(author.ev buyer.u.thd)  seller.u.thd
        buyer.u.thd
      =/  contact=(unit @ux)  (~(get by contacts.state) counter)
      =/  send-cards=(list card)
        ?~  contact  ~
        [(skein-send-card our.bowl u.contact (~(get by our-bundles.state) author.ev) author.ev keys.state [%evidence ev])]~
      ::  also send to moderator
      =/  esc=(unit escrow-config)  (~(get by escrows.state) thread-id.ev)
      =/  mod-cards=(list card)
        ?~  esc  ~
        =/  mod=(unit moderator-profile)  (~(get by moderators.state) moderator-id.u.esc)
        =/  mod-contact=(unit @ux)  ?~(mod ~ (~(get by contacts.state) nym-id.u.mod))
        ?~  mod-contact  ~
        [(skein-send-card our.bowl u.mod-contact (~(get by our-bundles.state) author.ev) author.ev keys.state [%evidence ev])]~
      :-  ;:(weld [(event-card [%evidence-submitted ev])]~ send-cards mod-cards)
      this
    ::
        %submit-verdict
      =/  thd=(unit silk-thread)  (~(get by threads.state) thread-id.verdict.cmd)
      ?~  thd  `this
      =/  ver=verdict  verdict.cmd
      =/  nc=@ux  (advance-chain chain.u.thd %verdict)
      =/  updated=silk-thread
        u.thd(thread-status %resolved, messages [[%verdict ver] messages.u.thd], chain nc, updated-at now.bowl)
      ::  WS1: stage — do NOT commit thread yet
      =/  resolve-card=card
        [%pass /market/resolve %agent [our.bowl %silk-market] %poke %noun !>([%resolve-dispute thread-id.ver ruling.ver])]
      ::  auto-trigger escrow action based on ruling
      =/  has-escrow=?  (~(has by escrows.state) thread-id.ver)
      =/  escrow-result=(quip card _this)
        ?.  has-escrow
          `this
        ?+  ruling.ver  `this
            %seller-wins
          ~&  [%silk-verdict %auto-release thread-id.ver]
          (handle-command [%release-escrow thread-id.ver])
        ::
            %buyer-wins
          ~&  [%silk-verdict %auto-refund thread-id.ver]
          (handle-command [%refund-escrow thread-id.ver])
        ::
        ::  WS5: real split settlement — validate shares and build multi-output
        ::
            %split
          =/  esc=(unit escrow-config)  (~(get by escrows.state) thread-id.ver)
          ?~  esc
            ~&  [%silk-verdict %split-no-escrow thread-id.ver]
            `this
          ::  validate shares sum to escrow amount
          =/  total=@ud  (add buyer-share.ver (add seller-share.ver moderator-share.ver))
          ?.  =(total amount.u.esc)
            ~&  [%silk-verdict %split-shares-mismatch thread-id.ver %total total %escrow amount.u.esc]
            `this
          ::  validate: no negative shares (all @ud so always >= 0)
          ::  validate: at least one share must be > 0
          ?.  (gth total 0)
            ~&  [%silk-verdict %split-zero-total thread-id.ver]
            `this
          ~&  [%silk-verdict %split-settlement thread-id.ver %buyer buyer-share.ver %seller seller-share.ver %mod moderator-share.ver]
          ::  WS5: block if account info not yet queried
          ?:  =(0 account-number.u.esc)
            ~&  [%silk-verdict %split-blocked-querying-account thread-id.ver]
            =.  escrow-status.state  (~(put by escrow-status.state) thread-id.ver %releasing)
            =/  query-cards=(list card)
              ?:  =('' multisig-address.u.esc)  ~
              :~  [%pass /zenith/query-account %agent [our.bowl %silk-zenith] %poke %noun !>([%query-escrow-account thread-id.ver multisig-address.u.esc])]
              ==
            [query-cards this]
          ::  build split outputs (only include non-zero shares)
          =/  outputs=(list [to=@t amount=@ud denom=@t])
            =/  acc=(list [to=@t amount=@ud denom=@t])  ~
            =?  acc  (gth buyer-share.ver 0)
              [[buyer-wallet.u.esc buyer-share.ver '$sZ'] acc]
            =?  acc  (gth seller-share.ver 0)
              [[seller-wallet.u.esc seller-share.ver '$sZ'] acc]
            =?  acc  (gth moderator-share.ver 0)
              =/  mod=(unit moderator-profile)  (~(get by moderators.state) moderator-id.u.esc)
              =/  mod-addr=@t  ?~(mod '' address.u.mod)
              ?:  =('' mod-addr)  acc
              [[mod-addr moderator-share.ver '$sZ'] acc]
            acc
          ::  need our escrow key to sign
          =/  priv=(unit @ux)  (~(get by escrow-keys.state) thread-id.ver)
          ?~  priv
            ~&  [%silk-verdict %split-no-key thread-id.ver]
            `this
          ::  build multi-output sign doc
          =/  sign-doc=@t
            %:  amino-json-sign-doc-multi-send:multisig
              multisig-address.u.esc
              outputs
              200.000  200.000  'zenith-stage1'
              account-number.u.esc  sequence.u.esc
            ==
          =/  sig=@ux  (sign-multisig-part:multisig sign-doc u.priv)
          ::  find our signer index
          =/  sorted-pks=(list @ux)
            (sort-pubkeys:multisig ~[buyer-pubkey.u.esc seller-pubkey.u.esc moderator-pubkey.u.esc])
          =/  our-pub=@ux  =+(secp256k1:secp:crypto (compress-point (priv-to-pub u.priv)))
          =/  our-idx=@ud
            =/  pks  sorted-pks
            =/  idx=@ud  0
            |-
            ?~  pks  0
            ?:  =(i.pks our-pub)  idx
            $(pks t.pks, idx +(idx))
          =.  escrow-status.state  (~(put by escrow-status.state) thread-id.ver %releasing)
          =/  existing=(map @ud @ux)  (~(gut by escrow-sigs.state) thread-id.ver ~)
          =.  existing  (~(put by existing) our-idx sig)
          =.  escrow-sigs.state  (~(put by escrow-sigs.state) thread-id.ver existing)
          ::  broadcast sig to counterparty
          =/  thd-for-split=(unit silk-thread)  (~(get by threads.state) thread-id.ver)
          ?~  thd-for-split
            ~&  [%silk-verdict %split-no-thread thread-id.ver]
            `this
          =/  we-are-seller=?  (~(has by nyms.state) seller.u.thd-for-split)
          =/  counter=nym-id  ?:(we-are-seller buyer.u.thd-for-split seller.u.thd-for-split)
          =/  contact=(unit @ux)  (~(get by contacts.state) counter)
          =/  our-nym=nym-id  ?:(we-are-seller seller.u.thd-for-split buyer.u.thd-for-split)
          =/  sig-cards=(list card)
            ?~  contact  ~
            [(skein-send-card our.bowl u.contact (~(get by our-bundles.state) our-nym) our-nym keys.state [%escrow-sign-release thread-id.ver sig our-idx])]~
          ::  check for local 2-sig assembly
          ?.  (gte ~(wyt by existing) 2)
            [;:(weld [(event-card [%escrow-releasing thread-id.ver])]~ sig-cards) this]
          ::  WS5: assemble multi-output split tx
          ~&  [%silk-verdict %split-assembling thread-id.ver]
          =/  sig-pairs=(list [@ud @ux])
            %+  sort  ~(tap by existing)
            |=([a=[@ud @ux] b=[@ud @ux]] (lth -.a -.b))
          =/  signer-indices=(list @ud)  (turn sig-pairs |=([i=@ud s=@ux] i))
          =/  signatures=(list @ux)      (turn sig-pairs |=([i=@ud s=@ux] s))
          =/  tx-hex=@t
            %:  assemble-split-tx:multisig
              multisig-address.u.esc
              outputs
              200.000  200.000  'zenith-stage1'
              account-number.u.esc  sequence.u.esc
              sorted-pks  signer-indices  signatures
            ==
          ~&  [%silk-verdict %split-tx-assembled thread-id.ver %hex-len (met 3 tx-hex) %outputs (lent outputs)]
          =.  escrow-txhex.state  (~(put by escrow-txhex.state) thread-id.ver tx-hex)
          =.  escrow-status.state  (~(put by escrow-status.state) thread-id.ver %released)
          =/  broadcast-card=card
            [%pass /zenith/broadcast %agent [our.bowl %silk-zenith] %poke %noun !>([%broadcast-escrow thread-id.ver tx-hex])]
          [;:(weld [(event-card [%escrow-released thread-id.ver])]~ sig-cards [broadcast-card]~) this]
        ==
      =.  this  +.escrow-result
      =/  ev-cards=(list card)
        (weld [(event-card [%thread-updated thread-id.ver %resolved])]~ -.escrow-result)
      =/  extra-send=(list card)  [resolve-card]~
      =/  dn=nym-id  (default-nym nyms.state)
      =/  [pid=@uv new-proposals=(map @uv pending-proposal) proposal-cards=(list card)]
        %:  stage-proposal
          our.bowl  now.bowl  thread-id.ver  updated  extra-send  ev-cards  dn
          pending-proposals.state  ~  ~  ~  ~  ~
          |=(p=@uv (market-advance-card our.bowl p thread-id.ver %resolved))
        ==
      =.  pending-proposals.state  new-proposals
      :-  proposal-cards
      this
    ::
        %register-moderator
      =/  mp=moderator-profile  moderator-profile.cmd
      =.  moderators.state  (~(put by moderators.state) id.mp mp)
      ::  broadcast profile + contact to all peers
      =/  active-peers=(list @p)
        %+  murn  ~(tap in peers.state)
        |=(p=@p ?:(=(p our.bowl) ~ `p))
      =/  peer-cards=(list card)
        %-  zing
        %+  turn  active-peers
        |=  p=@p
        =/  mod-bundle  (~(get by our-bundles.state) nym-id.mp)
        :~  (gossip-card our.bowl p (~(get by our-bundles.state) (default-nym nyms.state)) (default-nym nyms.state) keys.state [%moderator-profile mp])
            ?~  mod-bundle
              (gossip-card our.bowl p (~(get by our-bundles.state) (default-nym nyms.state)) (default-nym nyms.state) keys.state [%catalog ~ ~])
            (gossip-card our.bowl p (~(get by our-bundles.state) (default-nym nyms.state)) (default-nym nyms.state) keys.state [%catalog ~ [nym-id.mp u.mod-bundle]~])
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
        (turn active-peers |=(p=@p (gossip-card our.bowl p (~(get by our-bundles.state) (default-nym nyms.state)) (default-nym nyms.state) keys.state [%moderator-retracted id.cmd])))
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
      =/  contact=(unit @ux)  (~(get by contacts.state) seller.u.thd)
      ::  WS1: buyer is the actor for escrow-propose
      =/  send-cards=(list card)
        ?~  contact  ~
        [(skein-send-card our.bowl u.contact (~(get by our-bundles.state) buyer.u.thd) buyer.u.thd keys.state [%escrow-propose thread-id.cmd pub id.u.mod timeout.cmd ?~(buyer-nym '' wallet.u.buyer-nym)])]~
      =/  market-cards=(list card)
        [(market-advance-card our.bowl (sham [thread-id.cmd %escrow-proposed now.bowl]) thread-id.cmd %escrow-proposed)]~
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
      ::  WS1: seller is the actor for escrow-agree
      =/  contact=(unit @ux)  (~(get by contacts.state) buyer.u.thd)
      =/  send-cards=(list card)
        ?~  contact  ~
        [(skein-send-card our.bowl u.contact (~(get by our-bundles.state) seller.u.thd) seller.u.thd keys.state [%escrow-agree thread-id.cmd pub ?~(seller-nym '' wallet.u.seller-nym)])]~
      ::  Fix 6: notify moderator directly only, stripped wallet data
      ::  WS2: queue if moderator contact missing
      =/  mod=(unit moderator-profile)  (~(get by moderators.state) moderator-id.updated)
      =/  mod-contact=(unit @ux)  ?~(mod ~ (~(get by contacts.state) nym-id.u.mod))
      =/  notify-msg=silk-message  [%escrow-notify (escrow-notify-from-config updated) buyer.u.thd seller.u.thd]
      ::  WS2: store with seller as actor (seller agreed escrow)
      =?  awaiting-mod-contact.state  ?=(~ mod-contact)
        (~(put by awaiting-mod-contact.state) thread-id.cmd [moderator-id.updated seller.u.thd notify-msg])
      =/  mod-cards=(list card)
        ?~  mod-contact  ~
        [(skein-send-card our.bowl u.mod-contact (~(get by our-bundles.state) seller.u.thd) seller.u.thd keys.state notify-msg)]~
      ~&  [%silk-escrow %notify-moderator %mod-id moderator-id.updated %direct ?=(^ mod-contact)]
      =/  market-cards=(list card)
        [(market-advance-card our.bowl (sham [thread-id.cmd %escrow-agreed now.bowl]) thread-id.cmd %escrow-agreed)]~
      ::  auto-send invoice with multisig address
      =/  off=(unit offer)  (find-offer messages.u.thd)
      ?~  off
        :-  :(weld [(event-card [%escrow-agreed thread-id.cmd multisig-address.updated])]~ send-cards mod-cards market-cards)
        this
      ::  WS1: auto-invoice proceeds, market validates atomically
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
      =/  buyer-contact=(unit @ux)  (~(get by contacts.state) buyer.u.thd)
      =/  inv-cards=(list card)
        ?~  buyer-contact  ~
        ::  WS1: seller is the actor for invoice
        [(skein-send-card our.bowl u.buyer-contact (~(get by our-bundles.state) seller.u.thd) seller.u.thd keys.state [%invoice inv])]~
      =/  inv-mkt=(list card)
        [(market-advance-card our.bowl (sham [thread-id.cmd %invoiced now.bowl]) thread-id.cmd %invoiced)]~
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
      =/  contact=(unit @ux)  (~(get by contacts.state) counter)
      ::  WS1: buyer is the actor for escrow-funded
      =/  send-cards=(list card)
        ?~  contact  ~
        [(skein-send-card our.bowl u.contact (~(get by our-bundles.state) buyer.u.thd) buyer.u.thd keys.state [%escrow-funded thread-id.cmd tx-hash.cmd])]~
      =/  mkt-cards=(list card)
        [(market-advance-card our.bowl (sham [thread-id.cmd %escrowed now.bowl]) thread-id.cmd %escrowed)]~
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
      =/  mod-fee=@ud  (div (mul amount.u.esc moderator-fee-bps.u.esc) 10.000)
      =/  send-amt=@ud  (sub amount.u.esc mod-fee)
      =/  sign-doc=@t
        %:  amino-json-sign-doc-send:multisig
          multisig-address.u.esc  to-addr
          send-amt  '$sZ'
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
      =/  contact=(unit @ux)  (~(get by contacts.state) counter)
      ~&  [%silk-escrow %release-sign %idx our-idx %sigs ~(wyt by existing) %counter counter %has-contact ?=(^ contact)]
      ::  WS1: our role nym is the actor for escrow-sign-release
      =/  our-nym=nym-id  ?:(we-are-seller seller.u.thd buyer.u.thd)
      =/  send-cards=(list card)
        ?~  contact  ~
        [(skein-send-card our.bowl u.contact (~(get by our-bundles.state) our-nym) our-nym keys.state [%escrow-sign-release thread-id.cmd sig our-idx])]~
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
          send-amt  '$sZ'
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
      =/  contact=(unit @ux)  (~(get by contacts.state) counter)
      ~&  [%silk-escrow %refund-sign %idx our-idx %sigs ~(wyt by existing) %counter counter %has-contact ?=(^ contact)]
      ::  WS1: our role nym is the actor for escrow-sign-refund
      =/  our-nym=nym-id  ?:(we-are-buyer buyer.u.thd seller.u.thd)
      =/  send-cards=(list card)
        ?~  contact  ~
        [(skein-send-card our.bowl u.contact (~(get by our-bundles.state) our-nym) our-nym keys.state [%escrow-sign-refund thread-id.cmd sig our-idx])]~
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
        ['has_bundle' b+(~(has by our-bundles.state) id.n)]
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
          ['buyer_share' (numb:enjs:format buyer-share.v)]
          ['seller_share' (numb:enjs:format seller-share.v)]
          ['moderator_share' (numb:enjs:format moderator-share.v)]
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
          contacts=~(wyt by contacts.state)
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
      [%silk %mint-contact @ ~]
    ?.  ?=(%poke-ack -.sign)  `this
    =/  nid=nym-id  (slav %uv i.t.t.wire)
    ?^  p.sign
      ~&  [%silk-core %mint-contact-failed nid]
      ((slog u.p.sign) `this)
    ::  Fix 2: per-nym mint — scry skein for this nym's contact-bundle
    ~&  [%silk-core %mint-contact-ok nid]
    =/  result
      (mule |.(.^(* %gx /(scot %p our.bowl)/skein/(scot %da now.bowl)/contact/(scot %uv nid)/noun)))
    ?:  ?=(%| -.result)
      ~&  [%silk-core %mint-contact-scry-failed nid]
      `this
    =/  bundle=@ux  ;;(@ux p.result)
    ~&  [%silk-core %mint-contact-stored nid bundle]
    =.  our-bundles.state  (~(put by our-bundles.state) nid bundle)
    =.  bundle-minted-at.state  now.bowl
    `this
  ::
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
    ::  WS4: silk-zenith processed add-account — scry %zenith for address
    =/  tid=@uv  (slav %uv i.t.wire)
    =/  acc-name=@t  (scot %uv tid)
    ~&  [%silk-zenith-addr %scrying-account acc-name]
    ::  WS4: scry %zenith directly (silk-zenith proxies, but %zenith is source of truth)
    =/  result
      (mule |.(.^(* %gx /(scot %p our.bowl)/zenith/(scot %da now.bowl)/account/[acc-name]/noun)))
    ::  fall back to silk-zenith scry if %zenith desk not available
    =?  result  ?=(%| -.result)
      (mule |.(.^(* %gx /(scot %p our.bowl)/silk-zenith/(scot %da now.bowl)/account/[acc-name]/noun)))
    ?:  ?=(%| -.result)
      ~&  [%silk-zenith-addr %scry-failed acc-name]
      `this
    ::  WS4: try %zenith account type first (addr=@t), then silk zenith-account (address=@t)
    =/  addr=@t
      =/  zen-try  (mule |.(;;([addr=@t pub-key=@ux priv-key=@ux acc-num=@ud seq-num=@ud] p.result)))
      ?:  ?=(%& -.zen-try)  addr.p.zen-try
      =/  silk-try  (mule |.(;;((unit zenith-account) p.result)))
      ?.  ?=(%& -.silk-try)  ''
      ?~(p.silk-try '' address.u.p.silk-try)
    ?:  =('' addr)
      ~&  [%silk-zenith-addr %account-not-found acc-name]
      `this
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
    ::  WS1: stage via proposal — do NOT commit thread directly
    =/  nc=@ux  (advance-chain chain.u.thd %invoice)
    =/  updated=silk-thread
      u.thd(messages [[%invoice inv] messages.u.thd], chain nc, updated-at now.bowl)
    ::  WS1: seller is the actor for invoice
    =/  contact=(unit @ux)  (~(get by contacts.state) buyer.u.thd)
    =/  send-cards=(list card)
      ?~  contact  ~
      [(skein-send-card our.bowl u.contact (~(get by our-bundles.state) seller.u.thd) seller.u.thd keys.state [%invoice inv])]~
    =/  ev-cards=(list card)  [(event-card [%thread-updated tid %accepted])]~
    =/  [pid=@uv new-proposals=(map @uv pending-proposal) proposal-cards=(list card)]
      %:  stage-proposal
        our.bowl  now.bowl  tid  updated  send-cards  ev-cards  seller.u.thd
        pending-proposals.state  ~  ~  ~  ~  ~
        |=(p=@uv (market-advance-card our.bowl p tid %invoiced))
      ==
    =.  pending-proposals.state  new-proposals
    :-  proposal-cards
    this
  ::
      [%market *]
    ?-  -.sign
        %poke-ack
      ?~  p.sign  `this
      ::  WS3: log proposal rejections from market
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
      ::  WS1: proposal responses from authoritative market
      ?:  ?=([%proposal-approved @ @ @] raw)
        =/  [* pid=@uv ptid=@uv pto=@tas]  raw
        ~&  [%silk-market %proposal-approved %pid pid %tid ptid %to pto]
        ::  WS1: look up pending proposal and apply staged changes
        =/  pp=(unit pending-proposal)  (~(get by pending-proposals.state) pid)
        =.  pending-proposals.state  (~(del by pending-proposals.state) pid)
        ?~  pp
          ~&  [%silk-market %proposal-approved-no-pending pid]
          `this
        ::  apply staged thread
        =.  threads.state
          (~(put by threads.state) tid.staged-thread.u.pp thd.staged-thread.u.pp)
        ::  apply staged pending-acks
        =.  pending-acks.state
          =/  pa  pending-acks.state
          =/  entries=(list [@ux pending-msg-entry])  staged-pending-acks.u.pp
          |-
          ?~  entries  pa
          =/  [hash=@ux pme=pending-msg-entry]  i.entries
          =/  pm=pending-msg  [msg-hash.pme thread-id.pme target.pme msg.pme sent-at.pme attempts.pme sender.pme]
          $(entries t.entries, pa (~(put by pa) hash pm))
        ::  apply staged inventory
        =.  inventory.state
          =/  inv  inventory.state
          =/  entries=(list [listing-id @ud])  staged-inventory.u.pp
          |-
          ?~  entries  inv
          $(entries t.entries, inv (~(put by inv) i.entries))
        ::  apply staged escrow-status
        =.  escrow-status.state
          =/  es  escrow-status.state
          =/  entries=(list [@uv escrow-st])  staged-escrow-status.u.pp
          |-
          ?~  entries  es
          $(entries t.entries, es (~(put by es) i.entries))
        ::  apply staged escrow-sigs
        =.  escrow-sigs.state
          =/  sg  escrow-sigs.state
          =/  entries=(list [@uv (map @ud @ux)])  staged-escrow-sigs.u.pp
          |-
          ?~  entries  sg
          $(entries t.entries, sg (~(put by sg) i.entries))
        ::  apply staged escrow-keys
        =.  escrow-keys.state
          =/  ek  escrow-keys.state
          =/  entries=(list [@uv @ux])  staged-escrow-keys.u.pp
          |-
          ?~  entries  ek
          $(entries t.entries, ek (~(put by ek) i.entries))
        ::  emit staged outbound + event cards
        :-  (weld outbound-cards.u.pp event-cards.u.pp)
        this
      ?:  ?=([%proposal-rejected @ @ @ @] raw)
        =/  [* pid=@uv ptid=@uv pto=@tas reason=@t]  raw
        ~&  [%silk-market %proposal-rejected %pid pid %tid ptid %to pto %reason reason]
        ::  WS1: discard staged changes
        =.  pending-proposals.state  (~(del by pending-proposals.state) pid)
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
        [(market-advance-card our.bowl (sham [tid %escrowed now.bowl]) tid %escrowed)]~
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
      [%silk %rotate-bundles ~]
    ::  Fix 2: re-mint per-nym contact bundles and re-arm timer
    :_  this
    :_  (mint-all-nyms-cards our.bowl nyms.state)
    [%pass /silk/rotate-bundles %arvo %b %wait (add now.bowl ~h12)]
  ::
      [%silk %discover-peers ~]
    ::  probe skein relays for new silk peers, re-arm timer
    =/  probe-cards=(list card)
      (discover-peers-cards our.bowl now.bowl peers.state nyms.state keys.state our-bundles.state)
    ~?  (gth (lent probe-cards) 0)  [%silk-core %discover-peers %probing (lent probe-cards) %ships]
    :_  this
    :_  probe-cards
    [%pass /silk/discover-peers %arvo %b %wait (add now.bowl ~m5)]
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
    ::  resend and bump attempts — WS1: use stored actor nym
    =/  resend-cards=(list card)
      %+  turn  to-resend
      |=  [hash=@ux pm=pending-msg]
      (skein-send-card our.bowl target.pm (~(get by our-bundles.state) sender.pm) sender.pm keys.state msg.pm)
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
      ::  payment verified — auto-submit via proposal staging
      ~&  [%silk-pay-poll %verified tid %auto-submitting]
      =/  pp=payment-proof  [tid id.u.inv 'auto-pay-via-zenith' now.bowl]
      =/  nc=@ux  (advance-chain chain.u.thd %payment-proof)
      =/  updated=silk-thread
        u.thd(thread-status %paid, messages [[%payment-proof pp] messages.u.thd], chain nc, updated-at now.bowl)
      ::  WS1: do NOT commit thread yet — stage via proposal
      ::  WS1: buyer is the actor for auto-submitted payment-proof
      =/  contact=(unit @ux)  (~(get by contacts.state) seller.u.thd)
      =/  send-cards=(list card)
        ?~  contact  ~
        [(skein-send-card our.bowl u.contact (~(get by our-bundles.state) buyer.u.thd) buyer.u.thd keys.state [%payment-proof pp])]~
      =/  s-pend=(list [@ux pending-msg-entry])
        ?~  contact  ~
        =/  [hash=@ux pm=pending-msg]  (make-pending tid u.contact [%payment-proof pp] now.bowl buyer.u.thd)
        ~[[hash [hash tid u.contact [%payment-proof pp] now.bowl 0 buyer.u.thd]]]
      ::  stage escrow-status fund if active
      =/  has-esc-fund=?
        ?&  (~(has by escrows.state) tid)
            ?=(^ (~(get by escrow-status.state) tid))
            ?=(%agreed (need (~(get by escrow-status.state) tid)))
        ==
      =/  s-esc-st=(list [@uv escrow-st])
        ?.  has-esc-fund  ~
        ~&  [%silk-escrow %staging-fund-on-poll-payment tid]
        ~[[tid %funded]]
      =/  fund-cards=(list card)
        ?.  has-esc-fund  ~
        =/  fund-pid=@uv  (sham [tid %escrowed now.bowl])
        [(market-advance-card our.bowl fund-pid tid %escrowed)]~
      =/  query-cards=(list card)
        ?.  has-esc-fund  ~
        =/  esc=(unit escrow-config)  (~(get by escrows.state) tid)
        ?~  esc  ~
        ?:  =('' multisig-address.u.esc)  ~
        :~  [%pass /zenith/query-account %agent [our.bowl %silk-zenith] %poke %noun !>([%query-escrow-account tid multisig-address.u.esc])]
        ==
      ::  WS1: stage proposal — thread committed only on approval
      =/  ev-cards=(list card)
        ;:(weld [khan-card]~ [(event-card [%thread-updated tid %paid])]~ fund-cards query-cards)
      =/  [pid=@uv new-proposals=(map @uv pending-proposal) proposal-cards=(list card)]
        %:  stage-proposal
          our.bowl  now.bowl  tid  updated  send-cards  ev-cards  buyer.u.thd
          pending-proposals.state  s-pend  ~  s-esc-st  ~  ~
          |=(p=@uv (market-advance-card our.bowl p tid %paid))
        ==
      =.  pending-proposals.state  new-proposals
      :-  proposal-cards
      this
    ::  not yet confirmed — keep polling (up to 5min = 30 polls)
    =/  poll-card=card
      [%pass /zenith-poll/(scot %uv tid) %arvo %b %wait (add now.bowl ~s10)]
    :-  ~[khan-card poll-card]
    this
  ::
      [%escrow-poll @ ~]
    ::  poll multisig balance to confirm escrow release/refund tx
    =/  tid=@uv  (slav %uv i.t.wire)
    ?.  ?=([%behn %wake *] sign)  `this
    =/  esc=(unit escrow-config)  (~(get by escrows.state) tid)
    ?~  esc
      ~&  [%silk-escrow-poll %no-escrow tid]
      `this
    =/  st=(unit escrow-st)  (~(get by escrow-status.state) tid)
    ::  only poll if released or refunded (tx was broadcast)
    ?.  ?|  ?=([~ %released] st)
            ?=([~ %refunded] st)
        ==
      ~&  [%silk-escrow-poll %not-broadcast tid st]
      `this
    =/  ms-addr=@t  multisig-address.u.esc
    ?:  =('' ms-addr)
      ~&  [%silk-escrow-poll %no-address tid]
      `this
    ~&  [%silk-escrow-poll %checking tid ms-addr]
    =/  khan-card=card
      [%pass /escrow-check/(scot %uv tid) %arvo %k %fard %zenith %get-balances-by-addr %noun !>(ms-addr)]
    :-  [khan-card]~
    this
  ::
      [%escrow-check @ ~]
    ::  balance result for escrow confirmation
    =/  tid=@uv  (slav %uv i.t.wire)
    ?.  ?=([%khan %arow *] sign)  `this
    =/  res=(each cage tang)  +>.sign
    ?:  ?=(%| -.res)
      ~&  [%silk-escrow-poll %balance-check-failed tid]
      ::  retry in 10s
      =/  retry-card=card
        [%pass /escrow-poll/(scot %uv tid) %arvo %b %wait (add now.bowl ~s10)]
      :-  [retry-card]~
      this
    =/  bals  !<((list [denom=@t amount=@ud]) q.p.res)
    ::  find $sZ balance
    =/  bal=@ud
      =/  bs  bals
      |-
      ?~  bs  0
      ?:  =('$sZ' denom.i.bs)  amount.i.bs
      $(bs t.bs)
    ~&  [%silk-escrow-poll %balance tid bal]
    ::  if balance is less than the tx fee, the tx went through
    ?:  (lth bal 200.000)
      ~&  [%silk-escrow %tx-confirmed tid %remaining-balance bal]
      =.  escrow-status.state  (~(put by escrow-status.state) tid %confirmed)
      :-  [(event-card [%escrow-confirmed tid])]~
      this
    ::  still has funds — keep polling (up to 2min = 12 polls)
    =/  retry-card=card
      [%pass /escrow-poll/(scot %uv tid) %arvo %b %wait (add now.bowl ~s10)]
    :-  [retry-card]~
    this
  ==
++  on-fail   on-fail:def
--
