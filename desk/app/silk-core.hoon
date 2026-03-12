::  %silk-core: private commerce protocol agent
::
::  all peer messaging goes through %skein.
::  this agent never does direct ship-to-ship communication.
::  serves HTTP JSON API at /apps/silk/api/ for the frontend.
::
/-  *silk
/+  dbug, verb, default-agent, server
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
+$  current-state  state-4
+$  card  card:agent:gall
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
  ==
::
++  on-save
  !>(state)
::
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  =/  load-cards=(list card)
    :~  [%pass /eyre/connect %arvo %e %connect [~ /apps/silk/api] %silk-core]
        [%pass /silk/bind %agent [our.bowl %skein] %poke %skein-admin !>([%bind skein-app])]
        [%pass /silk/channel %agent [our.bowl %skein] %poke %skein-admin !>([%join-channel %silk-market %silk-core])]
    ==
  =/  try-4  (mule |.(!<(state-4 old)))
  ?:  ?=(%& -.try-4)
    =.  state  p.try-4
    [load-cards this]
  =/  try-3  (mule |.(!<(state-3 old)))
  ?:  ?=(%& -.try-3)
    =.  state
      :*  %4
          (~(run by nyms.p.try-3) migrate-nym)
          listings.p.try-3  threads.p.try-3
          routes.p.try-3  peers.p.try-3
          attestations.p.try-3  ~  next-seq.p.try-3
      ==
    [load-cards this]
  =/  try-2  (mule |.(!<(state-2 old)))
  ?:  ?=(%& -.try-2)
    =.  state
      :*  %4
          (~(run by nyms.p.try-2) migrate-nym)
          listings.p.try-2
          (~(run by threads.p.try-2) migrate-thread)
          routes.p.try-2  peers.p.try-2
          attestations.p.try-2  ~  next-seq.p.try-2
      ==
    [load-cards this]
  =/  try-1  (mule |.(!<(state-1 old)))
  ?:  ?=(%& -.try-1)
    =.  state
      :*  %4
          (~(run by nyms.p.try-1) migrate-nym)
          listings.p.try-1
          (~(run by threads.p.try-1) migrate-thread)
          routes.p.try-1  peers.p.try-1  ~  ~  next-seq.p.try-1
      ==
    [load-cards this]
  =/  try-0  (mule |.(!<(state-0 old)))
  ?:  ?=(%& -.try-0)
    =.  state
      :*  %4
          (~(run by nyms.p.try-0) migrate-nym)
          listings.p.try-0
          (~(run by threads.p.try-0) migrate-thread)
          routes.p.try-0  ~  ~  ~  next-seq.p.try-0
      ==
    [load-cards this]
  =.  state  [%4 ~ ~ ~ ~ ~ ~ ~ 1]
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
      :_  this
      :~  (event-card [%peer-added ship])
          (gossip-card our.bowl ship [%catalog our-listings our-routes])
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
      =/  catalog-cards=(list card)
        =/  our-listings=(list listing)  ~(val by listings.state)
        =/  our-routes=(list nym-route)
          %+  turn  ~(val by nyms.state)
          |=(n=pseudonym [id.n our.bowl %silk-core])
        (turn new-peers |=(p=@p (gossip-card our.bowl p [%catalog our-listings our-routes])))
      [(weld peer-cards catalog-cards) this]
    ?:  ?=([%channel-leave @ @] raw)
      =/  [* channel=@tas ship=@p]  raw
      ~&  [%silk-channel %peer-leave channel ship]
      `this
    ::  inbound skein delivery (opaque payload -> silk-message)
    ?.  ?=(@ raw)
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
      :_  this
      %+  weld
        [(gossip-card our.bowl ship [%catalog our-listings our-routes])]~
      ?:(new-peer [(event-card [%peer-added ship])]~ ~)
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
        %counter-offer   thread-id.msg
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
        %ping            thread-id.msg
        %pong            thread-id.msg
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
        :-  (weld ev-cards ack-cards)
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
    ::  acks don't advance state, just log receipt
    ?:  ?=(%ack -.msg)
      ~&  [%silk-ack %received tid msg-hash.msg]
      `this
    ::  update thread status based on inbound message type
    =/  new-status=thread-status
      ?:  ?=(?(%offer %counter-offer) -.msg)
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
    ::  send ack back to message sender
    =/  sender-nym=nym-id
      ?:  ?=(?(%offer %counter-offer %payment-proof %complete) -.msg)
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
    :-  (weld [(event-card [%message-received tid msg])]~ ack-cards)
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
        ?.  ?=(?(%accepted %paid %fulfilled %completed %disputed %resolved) thread-status.t)
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
          %-  pairs:enjs:format
          :~  ['thread_id' s+(scot %uv id.t)]
              ['listing_id' s+(scot %uv listing-id.t)]
              ['buyer' s+(scot %uv buyer.t)]
              ['seller' s+(scot %uv seller.t)]
              ['status' s+`@t`thread-status.t]
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
        [%stats ~]
      %-  give-json  :-  eyre-id
      %-  pairs:enjs:format
      :~  ['nyms' (numb:enjs:format ~(wyt by nyms.state))]
          ['listings' (numb:enjs:format ~(wyt by listings.state))]
          ['threads' (numb:enjs:format ~(wyt by threads.state))]
          ['routes' (numb:enjs:format ~(wyt by routes.state))]
          ['peers' (numb:enjs:format ~(wyt in peers.state))]
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
        %'post-listing'
      =/  f  (ot ~[title+so description+so price+ni currency+so nym+so])
      =/  [title=@t description=@t price=@ud currency=@t nym=@t]  (f jon)
      =/  id=listing-id  (sham [our.bowl now.bowl title])
      =/  seller=nym-id  (slav %uv nym)
      =/  lst=listing  [id seller title description price `@tas`currency now.bowl ~]
      [%post-listing lst]
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
      =/  oid=offer-id  (sham [our.bowl now.bowl lid-uv])
      =/  tid=thread-id  (sham [lid-uv buyer-uv seller-uv])
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
    ::  derive pay address from seller's wallet
    =/  seller-nym=(unit pseudonym)  (~(get by nyms.state) seller.u.thd)
    ?~  seller-nym
      :_(this (err-response eyre-id 'seller nym not found'))
    ?:  =('' wallet.u.seller-nym)
      :_(this (err-response eyre-id 'seller has no wallet set'))
    =/  inv=invoice
      :*  (sham [our.bowl now.bowl tid])
          tid
          id.u.off
          seller.u.thd
          amount.u.off
          currency.u.off
          wallet.u.seller-nym
          (add now.bowl ~d7)
      ==
    =/  result  (handle-command [%send-invoice inv])
    :_  +.result
    %+  weld  -.result
    (ok-response eyre-id)
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
    :_  this
    %+  weld  [(event-card [%thread-updated tid %completed])]~
    %+  weld  send-cards
    (ok-response eyre-id)
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
    =/  att=attestation
      :*  (sham [our.bowl now.bowl tid issuer])
          subject
          issuer
          %completion
          sc.parsed
          nt.parsed
          now.bowl
          `@ux`0
      ==
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
    ::  look up seller wallet
    =/  seller-nym=(unit pseudonym)  (~(get by nyms.state) seller.u.thd)
    =/  seller-wallet=@t  ?~(seller-nym '' wallet.u.seller-nym)
    ::  look up invoice
    =/  inv=(unit invoice)  (find-invoice messages.u.thd)
    =/  inv-amount=@ud  ?~(inv 0 amount.u.inv)
    ::  look up existing verification
    =/  ver=(unit [verified=? balance=@ud checked-at=@da])
      (~(get by verifications.state) tid)
    ::  fire balance check thread via %khan if seller has a wallet
    =/  khan-cards=(list card)
      ?:  =('' seller-wallet)  ~
      :~  [%pass /zenith-check/(scot %uv tid) %arvo %k %fard %zenith %get-balances-by-addr %noun !>(seller-wallet)]
      ==
    ::  return current state immediately
    =/  resp=json
      %-  pairs:enjs:format
      :~  ['thread_id' s+(scot %uv tid)]
          ['seller_wallet' s+seller-wallet]
          ['invoice_amount' (numb:enjs:format inv-amount)]
          ['status' s+`@t`thread-status.u.thd]
          ['verified' ?~(ver ~ b+verified.u.ver)]
          ['balance' ?~(ver ~ (numb:enjs:format balance.u.ver))]
          ['checked_at' ?~(ver ~ (numb:enjs:format (div (sub checked-at.u.ver ~1970.1.1) ~s1)))]
      ==
    :_  this
    (weld khan-cards (give-json eyre-id resp))
  ::
  ::  command handler (shared by poke and http post)
  ::
  ++  handle-command
    |=  cmd=silk-command
    ^-  (quip card _this)
    ?-  -.cmd
        %create-nym
      =/  id=nym-id  (sham [our.bowl now.bowl label.cmd])
      =/  seed=@ux  (shaz (jam [id now.bowl eny.bowl]))
      =/  nym=pseudonym  [id label.cmd seed wallet.cmd now.bowl]
      =.  nyms.state  (~(put by nyms.state) id nym)
      :-  [(event-card [%nym-created nym])]~
      this
    ::
        %drop-nym
      =.  nyms.state  (~(del by nyms.state) id.cmd)
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
      =/  send-cards=(list card)
        ?~  route
          ~&  [%silk-warn %no-route-for-seller seller.o]
          ~
        :~  (skein-send-card our.bowl u.route [%offer o])
            (skein-send-card our.bowl u.route [%catalog ~ [buyer-route]~])
        ==
      :-  (weld [(event-card [%thread-opened thd])]~ send-cards)
      this
    ::
        %accept-offer
      =/  thd=(unit silk-thread)  (~(get by threads.state) thread-id.cmd)
      ?~  thd  `this
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
      :-  (weld [(event-card [%thread-updated thread-id.cmd %accepted])]~ send-cards)
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
      :-  (weld [(event-card [%thread-updated thread-id.cmd %cancelled])]~ send-cards)
      this
    ::
        %send-invoice
      =/  thd=(unit silk-thread)  (~(get by threads.state) thread-id.invoice.cmd)
      ?~  thd  `this
      =/  inv=invoice  invoice.cmd
      =/  nc=@ux  (advance-chain chain.u.thd %invoice)
      =/  updated=silk-thread
        u.thd(messages [[%invoice inv] messages.u.thd], chain nc, updated-at now.bowl)
      =.  threads.state  (~(put by threads.state) thread-id.inv updated)
      =/  route=(unit nym-route)  (~(get by routes.state) buyer.u.thd)
      =/  send-cards=(list card)
        ?~  route  ~
        [(skein-send-card our.bowl u.route [%invoice inv])]~
      :-  (weld [(event-card [%thread-updated thread-id.inv %accepted])]~ send-cards)
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
      :-  (weld [(event-card [%thread-updated thread-id.pp %paid])]~ send-cards)
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
      :-  (weld [(event-card [%thread-updated thread-id.ful %fulfilled])]~ send-cards)
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
      :-  (weld [(event-card [%thread-updated thread-id.dis %disputed])]~ send-cards)
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
      :-  [(event-card [%thread-updated thread-id.ver %resolved])]~
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
  ==
++  on-arvo
  |=  [=wire sign=sign-arvo]
  ^-  (quip card _this)
  ?+  wire  (on-arvo:def wire sign)
      [%eyre *]
    `this
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
    =/  bals=(list [denom=@t amount=@ud])
      (^:((list [denom=@t amount=@ud])) q.p.p.sign)
    ::  find sZ/znt balance
    =/  bal=@ud
      =/  items=(list [denom=@t amount=@ud])  bals
      |-
      ?~  items  0
      ?:  |(=('znt' denom.i.items) =('sZ' denom.i.items) =('sz' denom.i.items))
        amount.i.items
      $(items t.items)
    ::  look up invoice amount for this thread
    =/  thd=(unit silk-thread)  (~(get by threads.state) tid)
    =/  inv-amount=@ud
      ?~  thd  0
      =/  inv=(unit invoice)
        =/  ms=(list silk-message)  messages.u.thd
        |-
        ?~  ms  ~
        ?:  ?=(%invoice -.i.ms)  `+.i.ms
        $(ms t.ms)
      ?~(inv 0 amount.u.inv)
    ::  verified if balance >= invoice amount
    =/  verified=?  (gte bal inv-amount)
    ~&  [%silk-verify tid %balance bal %required inv-amount %verified verified]
    =.  verifications.state
      (~(put by verifications.state) tid [verified bal now.bowl])
    `this
  ==
++  on-fail   on-fail:def
--
