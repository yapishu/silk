::  %silk-core: private commerce protocol agent
::
::  all peer messaging goes through %skein.
::  this agent never does direct ship-to-ship communication.
::  serves HTTP JSON API at /apps/silk/api/ for the frontend.
::
/-  *silk
/+  dbug, verb, default-agent, server
|%
+$  state-0
  $:  %0
      nyms=(map nym-id pseudonym)
      listings=(map listing-id listing)
      threads=(map thread-id silk-thread)
      routes=(map nym-id nym-route)
      next-seq=@ud
  ==
::
+$  state-1
  $:  %1
      nyms=(map nym-id pseudonym)
      listings=(map listing-id listing)
      threads=(map thread-id silk-thread)
      routes=(map nym-id nym-route)
      peers=(set @p)
      next-seq=@ud
  ==
::
+$  current-state  state-1
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
  =/  new  (mule |.(!<(current-state old)))
  ?:  ?=(%& -.new)
    =.  state  p.new
    :_  this
    :~  [%pass /eyre/connect %arvo %e %connect [~ /apps/silk/api] %silk-core]
        [%pass /silk/bind %agent [our.bowl %skein] %poke %skein-admin !>([%bind skein-app])]
        [%pass /silk/channel %agent [our.bowl %skein] %poke %skein-admin !>([%join-channel %silk-market %silk-core])]
    ==
  =/  old-try  (mule |.(!<(state-0 old)))
  =.  state
    ?:  ?=(%& -.old-try)
      [%1 nyms.p.old-try listings.p.old-try threads.p.old-try routes.p.old-try ~ next-seq.p.old-try]
    [%1 ~ ~ ~ ~ ~ 1]
  :_  this
  :~  [%pass /eyre/connect %arvo %e %connect [~ /apps/silk/api] %silk-core]
      [%pass /silk/bind %agent [our.bowl %skein] %poke %skein-admin !>([%bind skein-app])]
      [%pass /silk/channel %agent [our.bowl %skein] %poke %skein-admin !>([%join-channel %silk-market %silk-core])]
  ==
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
    ::  thread-routed messages
    =/  tid=thread-id
      ?+  -.msg  (sham raw)
        %offer          thread-id.msg
        %counter-offer  thread-id.msg
        %accept         thread-id.msg
        %reject         thread-id.msg
        %invoice        thread-id.msg
        %payment-proof  thread-id.msg
        %fulfill        thread-id.msg
        %dispute        thread-id.msg
        %verdict        thread-id.msg
        %ping           thread-id.msg
        %pong           thread-id.msg
      ==
    =/  thd=(unit silk-thread)  (~(get by threads.state) tid)
    ?~  thd
      ::  create thread on first contact (e.g. seller receives offer)
      ?.  ?=(%offer -.msg)
        :-  [(event-card [%message-received tid msg])]~
        this
      =/  o=offer  +.msg
      =/  new-thd=silk-thread
        [tid listing-id.o buyer.o seller.o %open [[%offer o] ~] now.bowl now.bowl]
      =.  threads.state  (~(put by threads.state) tid new-thd)
      :-  :~  (event-card [%thread-opened new-thd])
              (event-card [%message-received tid msg])
          ==
      this
    ::  update thread status based on inbound message type
    =/  new-status=thread-status
      ?:  ?=(%accept -.msg)
        %accepted
      ?:  ?=(%reject -.msg)
        %cancelled
      ?:  ?=(%payment-proof -.msg)
        %paid
      ?:  ?=(%fulfill -.msg)
        %fulfilled
      ?:  ?=(%dispute -.msg)
        %disputed
      ?:  ?=(%verdict -.msg)
        %resolved
      thread-status.u.thd
    =/  updated=silk-thread
      u.thd(thread-status new-status, messages [msg messages.u.thd], updated-at now.bowl)
    =.  threads.state  (~(put by threads.state) tid updated)
    :-  [(event-card [%message-received tid msg])]~
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
              ['updated_at' (numb:enjs:format (div (sub updated-at.t ~1970.1.1) ~s1))]
          ==
      ==
    ::
        [%reputation ~]
      %-  give-json  :-  eyre-id
      %-  pairs:enjs:format
      :~  ['scores' [%a ~]]
          ['issued' [%a ~]]
          ['received' [%a ~]]
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
      =/  label=@t  ((ot ~[label+so]) jon)
      [%create-nym label]
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
  ++  find-invoice-id
    |=  msgs=(list silk-message)
    ^-  (unit invoice-id)
    ?~  msgs  ~
    ?:  ?=(%invoice -.i.msgs)  `id.+.i.msgs
    $(msgs t.msgs)
  ::
  ++  handle-api-invoice
    |=  [eyre-id=@ta jon=json]
    ^-  (quip card _this)
    =,  dejs:format
    =/  f  (ot ~['thread_id'^so 'pay_address'^so])
    =/  [tid-t=@t pa=@t]  (f jon)
    =/  tid=@uv  (slav %uv tid-t)
    =/  thd=(unit silk-thread)  (~(get by threads.state) tid)
    ?~  thd
      :_(this (err-response eyre-id 'thread not found'))
    =/  off=(unit offer)  (find-offer messages.u.thd)
    ?~  off
      :_(this (err-response eyre-id 'no offer in thread'))
    =/  inv=invoice
      :*  (sham [our.bowl now.bowl tid])
          tid
          id.u.off
          seller.u.thd
          amount.u.off
          currency.u.off
          pa
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
    =,  dejs:format
    =/  f  (ot ~['thread_id'^so 'tx_hash'^so])
    =/  [tid-t=@t txh-t=@t]  (f jon)
    =/  tid=@uv  (slav %uv tid-t)
    =/  thd=(unit silk-thread)  (~(get by threads.state) tid)
    ?~  thd
      :_(this (err-response eyre-id 'thread not found'))
    =/  inv-id=invoice-id
      =/  found  (find-invoice-id messages.u.thd)
      ?~(found (sham tid) u.found)
    =/  pp=payment-proof
      :*  tid
          inv-id
          `@ux`(sham txh-t)
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
    =,  dejs:format
    =/  f  (ot ~['thread_id'^so note+so])
    =/  [tid-t=@t note=@t]  (f jon)
    =/  tid=@uv  (slav %uv tid-t)
    =/  thd=(unit silk-thread)  (~(get by threads.state) tid)
    ?~  thd
      :_(this (err-response eyre-id 'thread not found'))
    =/  off=(unit offer)  (find-offer messages.u.thd)
    =/  oid=offer-id  ?~(off (sham tid) id.u.off)
    =/  ful=fulfillment
      :*  tid
          oid
          note
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
    =,  dejs:format
    =/  tid-t=@t  ((ot ~['thread_id'^so]) jon)
    =/  tid=@uv  (slav %uv tid-t)
    =/  thd=(unit silk-thread)  (~(get by threads.state) tid)
    ?~  thd
      :_(this (err-response eyre-id 'thread not found'))
    =/  updated=silk-thread
      u.thd(thread-status %completed, updated-at now.bowl)
    =.  threads.state  (~(put by threads.state) tid updated)
    :_  this
    %+  weld
      [(event-card [%thread-updated tid %completed])]~
    (ok-response eyre-id)
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
      =/  nym=pseudonym  [id label.cmd seed now.bowl]
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
      :-  [(event-card [%listing-retracted id.cmd])]~
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
          u.existing(messages [[%offer o] messages.u.existing], updated-at now.bowl)
        [tid listing-id.o buyer.o seller.o %open [[%offer o] ~] now.bowl now.bowl]
      =.  threads.state  (~(put by threads.state) tid thd)
      =/  route=(unit nym-route)  (~(get by routes.state) seller.o)
      =/  send-cards=(list card)
        ?~  route  ~
        [(skein-send-card our.bowl u.route [%offer o])]~
      :-  (weld [(event-card [%thread-opened thd])]~ send-cards)
      this
    ::
        %accept-offer
      =/  thd=(unit silk-thread)  (~(get by threads.state) thread-id.cmd)
      ?~  thd  `this
      =/  acc=accept  [thread-id.cmd offer-id.cmd now.bowl]
      =/  updated=silk-thread
        u.thd(thread-status %accepted, messages [[%accept acc] messages.u.thd], updated-at now.bowl)
      =.  threads.state  (~(put by threads.state) thread-id.cmd updated)
      =/  route=(unit nym-route)  (~(get by routes.state) buyer.u.thd)
      =/  send-cards=(list card)
        ?~  route  ~
        [(skein-send-card our.bowl u.route [%accept acc])]~
      :-  (weld [(event-card [%thread-updated thread-id.cmd %accepted])]~ send-cards)
      this
    ::
        %reject-offer
      =/  thd=(unit silk-thread)  (~(get by threads.state) thread-id.cmd)
      ?~  thd  `this
      =/  rej=reject  [thread-id.cmd offer-id.cmd reason.cmd now.bowl]
      =/  updated=silk-thread
        u.thd(thread-status %cancelled, messages [[%reject rej] messages.u.thd], updated-at now.bowl)
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
      =/  updated=silk-thread
        u.thd(messages [[%invoice inv] messages.u.thd], updated-at now.bowl)
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
      =/  updated=silk-thread
        u.thd(thread-status %paid, messages [[%payment-proof pp] messages.u.thd], updated-at now.bowl)
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
      =/  updated=silk-thread
        u.thd(thread-status %fulfilled, messages [[%fulfill ful] messages.u.thd], updated-at now.bowl)
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
      =/  updated=silk-thread
        u.thd(thread-status %disputed, messages [[%dispute dis] messages.u.thd], updated-at now.bowl)
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
      =/  updated=silk-thread
        u.thd(thread-status %resolved, messages [[%verdict ver] messages.u.thd], updated-at now.bowl)
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
        ['created_at' (numb:enjs:format (div (sub created-at.n ~1970.1.1) ~s1))]
    ==
  ::
  ++  listing-to-json
    |=  l=listing
    ^-  json
    =/  nym=(unit pseudonym)  (~(get by nyms.state) seller.l)
    %-  pairs:enjs:format
    :~  ['id' s+(scot %uv id.l)]
        ['seller' s+(scot %uv seller.l)]
        ['seller_label' ?~(nym ~ s+label.u.nym)]
        ['mine' b+?=(^ nym)]
        ['title' s+title.l]
        ['description' s+description.l]
        ['price' (numb:enjs:format price.l)]
        ['currency' s+currency.l]
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
    :~  ['id' s+(scot %uv id.t)]
        ['listing_id' s+(scot %uv listing-id.t)]
        ['buyer' s+(scot %uv buyer.t)]
        ['seller' s+(scot %uv seller.t)]
        ['status' s+`@t`thread-status.t]
        ['message_count' (numb:enjs:format (lent messages.t))]
        ['amount' (numb:enjs:format amount.offer-data)]
        ['currency' s+`@t`cur.offer-data]
        ['started_at' (numb:enjs:format (div (sub started-at.t ~1970.1.1) ~s1))]
        ['updated_at' (numb:enjs:format (div (sub updated-at.t ~1970.1.1) ~s1))]
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
  ==
++  on-fail   on-fail:def
--
