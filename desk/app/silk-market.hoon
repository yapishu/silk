::  %silk-market: marketplace order state machine
::
::  manages the lifecycle of orders: listing -> offer -> accept ->
::  invoice -> payment -> fulfillment -> completion.
::  enforces valid state transitions.
::  triggers reputation attestations on completion.
::  WS1: authoritative proposal/approval gate for silk-core.
::  WS4: timeout-driven stale order cancellation and dispute deadlines.
::
/-  *silk
/+  dbug, verb, default-agent
|%
+$  escrow-status
  $?  %held        ::  funds committed, awaiting fulfillment
      %released    ::  released to seller
      %refunded    ::  returned to buyer
      %disputed    ::  frozen pending dispute resolution
  ==
::
+$  escrow-record
  $:  thread-id=@uv
      offer-id=offer-id
      buyer=nym-id
      seller=nym-id
      amount=@ud
      currency=@tas
      =escrow-status
      tx-hash=(unit @ux)
      created-at=@da
      resolved-at=(unit @da)
  ==
::
+$  order
  $:  thread-id=@uv
      listing-id=listing-id
      buyer=nym-id
      seller=nym-id
      offer-id=offer-id
      amount=@ud
      currency=@tas
      =order-status
      escrow=(unit escrow-record)
      created-at=@da
      updated-at=@da
  ==
::
+$  order-status
  $?  %offered            ::  buyer made an offer
      %accepted           ::  seller accepted
      %escrow-proposed    ::  buyer proposed escrow w/ moderator
      %escrow-agreed      ::  seller agreed, multisig derived
      %invoiced           ::  seller sent invoice
      %paid               ::  buyer submitted payment proof
      %escrowed           ::  payment confirmed in escrow
      %fulfilled          ::  seller delivered goods
      %completed          ::  buyer confirmed, order done
      %disputed           ::  dispute filed
      %resolved           ::  dispute resolved
      %cancelled          ::  cancelled
  ==
::
::  valid state transitions
::
++  valid-transition
  |=  [from=order-status to=order-status]
  ^-  ?
  ?+  [from to]  %.n
    [%offered %accepted]               %.y
    [%offered %cancelled]              %.y
    [%accepted %escrow-proposed]       %.y  ::  buyer proposes escrow
    [%accepted %invoiced]              %.y  ::  direct (no escrow)
    [%accepted %cancelled]             %.y
    [%escrow-proposed %escrow-agreed]  %.y  ::  seller agrees to escrow
    [%escrow-proposed %cancelled]      %.y
    [%escrow-agreed %invoiced]         %.y  ::  proceed to invoice after escrow setup
    [%escrow-agreed %cancelled]        %.y
    [%invoiced %paid]                  %.y
    [%invoiced %cancelled]             %.y
    [%paid %escrowed]                  %.y
    [%escrowed %fulfilled]             %.y
    [%escrowed %disputed]              %.y
    [%fulfilled %completed]            %.y
    [%fulfilled %disputed]             %.y
    [%disputed %resolved]              %.y
    [%disputed %escrowed]              %.y  ::  dismissed dispute returns to escrowed
    [%completed %completed]            %.y
  ==
::
+$  market-command
  $%  [%create-order thread-id=@uv listing-id=listing-id buyer=nym-id seller=nym-id offer-id=offer-id amount=@ud currency=@tas]
      [%advance thread-id=@uv to=order-status]
      [%set-escrow thread-id=@uv tx-hash=@ux]
      [%resolve-escrow thread-id=@uv =escrow-status]
      [%resolve-dispute thread-id=@uv ruling=ruling-kind]
      [%cancel-stale threshold=@dr]
      ::  WS1: proposal-based commands — returns approved/rejected on /market-events
      [%propose-create proposal-id=@uv thread-id=@uv listing-id=listing-id buyer=nym-id seller=nym-id offer-id=offer-id amount=@ud currency=@tas]
      [%propose-advance proposal-id=@uv thread-id=@uv to=order-status]
  ==
::
+$  market-event
  $%  [%order-created =order]
      [%order-advanced thread-id=@uv from=order-status to=order-status]
      [%order-completed thread-id=@uv buyer=nym-id seller=nym-id]
      [%escrow-set thread-id=@uv tx-hash=@ux]
      [%escrow-resolved thread-id=@uv =escrow-status]
      [%dispute-filed thread-id=@uv]
      [%dispute-resolved thread-id=@uv ruling=ruling-kind]
      [%stale-cancelled count=@ud]
      [%invalid-transition thread-id=@uv from=order-status to=order-status]
      ::  WS1: proposal responses
      [%proposal-approved proposal-id=@uv thread-id=@uv to=order-status]
      [%proposal-rejected proposal-id=@uv thread-id=@uv to=order-status reason=@t]
  ==
::
::  WS4: timeout tracking for active orders
::
+$  timeout-entry
  $:  =thread-id
      kind=timeout-kind
      deadline=@da
  ==
::
+$  timeout-kind
  $?  %invoice-expiry       ::  invoice must arrive before deadline
      %escrow-inactivity    ::  funded escrow idle too long -> auto-refund
      %dispute-deadline     ::  moderator must rule before deadline
  ==
::
+$  state-0
  $:  %0
      orders=(map @uv order)
      listings=(map listing-id listing)
      timeouts=(map @uv timeout-entry)    ::  timeout tracking
  ==
::
+$  current-state  state-0
+$  card  card:agent:gall
::
++  event-card
  |=  ev=market-event
  ^-  card
  [%give %fact [/market-events]~ %noun !>(ev)]
::
::  trigger reputation attestation on order completion
::
++  attest-completion
  |=  [ord=order our=ship now=@da eny=@]
  ^-  (list card)
  =/  att-id=attest-id  (sham [thread-id.ord now eny])
  ::  buyer attests seller fulfilled
  =/  buyer-att=attestation
    [att-id seller.ord buyer.ord %fulfillment 1 'order-completed' now 0x0]
  ::  seller attests buyer paid
  =/  seller-att=attestation
    [(sham [att-id 'seller']) buyer.ord seller.ord %payment 1 'order-completed' now 0x0]
  ::  poke silk-rep to record both
  :~  [%pass /rep/buyer %agent [our %silk-rep] %poke %noun !>([%issue buyer-att])]
      [%pass /rep/seller %agent [our %silk-rep] %poke %noun !>([%issue seller-att])]
  ==
::
::  WS4: check and fire expired timeouts
::
++  check-timeouts
  |=  [now=@da timeouts=(map @uv timeout-entry) orders=(map @uv order)]
  ^-  [expired=(list @uv) cancels=(list @uv)]
  =/  entries=(list [@uv timeout-entry])  ~(tap by timeouts)
  =/  expired=(list @uv)  ~
  =/  cancels=(list @uv)  ~
  |-
  ?~  entries  [expired cancels]
  =/  [tid=@uv te=timeout-entry]  i.entries
  ?.  (gte now deadline.te)
    $(entries t.entries)
  ::  timeout fired
  ?-  kind.te
      %invoice-expiry
    ::  cancel order if still in invoiceable state
    =/  ord=(unit order)  (~(get by orders) thread-id.te)
    ?~  ord  $(entries t.entries, expired [tid expired])
    ?.  ?=(?(%accepted %escrow-agreed) order-status.u.ord)
      $(entries t.entries, expired [tid expired])
    $(entries t.entries, expired [tid expired], cancels [thread-id.te cancels])
  ::
      %escrow-inactivity
    ::  cancel escrowed orders (silk-core handles refund logic)
    =/  ord=(unit order)  (~(get by orders) thread-id.te)
    ?~  ord  $(entries t.entries, expired [tid expired])
    ?.  =(%escrowed order-status.u.ord)
      $(entries t.entries, expired [tid expired])
    $(entries t.entries, expired [tid expired], cancels [thread-id.te cancels])
  ::
      %dispute-deadline
    ::  cancel disputed orders that timed out
    =/  ord=(unit order)  (~(get by orders) thread-id.te)
    ?~  ord  $(entries t.entries, expired [tid expired])
    ?.  =(%disputed order-status.u.ord)
      $(entries t.entries, expired [tid expired])
    $(entries t.entries, expired [tid expired], cancels [thread-id.te cancels])
  ==
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
  ::  WS4: start timeout poll timer
  :_  this
  :~  [%pass /market/timeout-poll %arvo %b %wait (add now.bowl ~m5)]
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
  ::  start timeout poll timer on load
  :_  this
  :~  [%pass /market/timeout-poll %arvo %b %wait (add now.bowl ~m5)]
  ==
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?+  mark  (on-poke:def mark vase)
      %noun
    ?>  =(our src):bowl
    =/  cmd=market-command  ;;(market-command q.vase)
    ?-  -.cmd
        %create-order
      =/  ord=order
        :*  thread-id.cmd
            listing-id.cmd
            buyer.cmd
            seller.cmd
            offer-id.cmd
            amount.cmd
            currency.cmd
            %offered
            ~
            now.bowl
            now.bowl
        ==
      =.  orders.state  (~(put by orders.state) thread-id.cmd ord)
      :-  [(event-card [%order-created ord])]~
      this
    ::
        %advance
      =/  ord=(unit order)  (~(get by orders.state) thread-id.cmd)
      ?~  ord  `this
      ::  no-op if already at target status
      ?:  =(order-status.u.ord to.cmd)  `this
      ?.  (valid-transition order-status.u.ord to.cmd)
        :-  [(event-card [%invalid-transition thread-id.cmd order-status.u.ord to.cmd])]~
        this
      =/  updated=order  u.ord(order-status to.cmd, updated-at now.bowl)
      ::  auto-freeze escrow when dispute is filed
      =?  updated  ?&(=(to.cmd %disputed) ?=(^ escrow.updated))
        =/  frozen-esc=escrow-record  u.escrow.updated(escrow-status %disputed)
        updated(escrow `frozen-esc)
      =.  orders.state  (~(put by orders.state) thread-id.cmd updated)
      =/  base-cards=(list card)
        :~  (event-card [%order-advanced thread-id.cmd order-status.u.ord to.cmd])
        ==
      =/  dispute-cards=(list card)
        ?.  =(to.cmd %disputed)  ~
        ::  WS4: set dispute deadline (7 days for moderator to rule)
        =/  te-id=@uv  (sham [thread-id.cmd %dispute now.bowl])
        =.  timeouts.state  (~(put by timeouts.state) te-id [thread-id.cmd %dispute-deadline (add now.bowl ~d7)])
        [(event-card [%dispute-filed thread-id.cmd])]~
      ::  WS4: set invoice expiry timeout on accepted
      =?  timeouts.state  =(to.cmd %accepted)
        =/  te-id=@uv  (sham [thread-id.cmd %invoice now.bowl])
        (~(put by timeouts.state) te-id [thread-id.cmd %invoice-expiry (add now.bowl ~d7)])
      ::  WS4: set escrow inactivity timeout on escrowed
      =?  timeouts.state  =(to.cmd %escrowed)
        =/  te-id=@uv  (sham [thread-id.cmd %escrow now.bowl])
        (~(put by timeouts.state) te-id [thread-id.cmd %escrow-inactivity (add now.bowl ~d14)])
      ::  on completion, trigger reputation attestations
      =/  rep-cards=(list card)
        ?.  =(to.cmd %completed)  ~
        :-  (event-card [%order-completed thread-id.cmd buyer.u.ord seller.u.ord])
        (attest-completion updated our.bowl now.bowl eny.bowl)
      [(zing ~[base-cards dispute-cards rep-cards]) this]
    ::
        %set-escrow
      =/  ord=(unit order)  (~(get by orders.state) thread-id.cmd)
      ?~  ord  `this
      =/  esc=escrow-record
        :*  thread-id.cmd
            offer-id.u.ord
            buyer.u.ord
            seller.u.ord
            amount.u.ord
            currency.u.ord
            %held
            `tx-hash.cmd
            now.bowl
            ~
        ==
      =/  updated=order  u.ord(escrow `esc, order-status %escrowed, updated-at now.bowl)
      =.  orders.state  (~(put by orders.state) thread-id.cmd updated)
      :-  [(event-card [%escrow-set thread-id.cmd tx-hash.cmd])]~
      this
    ::
        %resolve-escrow
      =/  ord=(unit order)  (~(get by orders.state) thread-id.cmd)
      ?~  ord  `this
      ?~  escrow.u.ord  `this
      =/  updated-esc=escrow-record
        u.escrow.u.ord(escrow-status escrow-status.cmd, resolved-at `now.bowl)
      =/  updated=order  u.ord(escrow `updated-esc, updated-at now.bowl)
      =.  orders.state  (~(put by orders.state) thread-id.cmd updated)
      :-  [(event-card [%escrow-resolved thread-id.cmd escrow-status.cmd])]~
      this
    ::
        %resolve-dispute
      =/  ord=(unit order)  (~(get by orders.state) thread-id.cmd)
      ?~  ord  `this
      ?.  =(order-status.u.ord %disputed)  `this
      ::  resolve escrow based on ruling
      =/  esc-status=escrow-status
        ?-  ruling.cmd
          %buyer-wins   %refunded
          %seller-wins  %released
          %split        %released   ::  WS5: split settlement (multi-output at escrow layer)
          %dismissed    %held       ::  return to held, order goes back to escrowed
        ==
      =/  updated-esc=(unit escrow-record)
        ?~  escrow.u.ord  ~
        `u.escrow.u.ord(escrow-status esc-status, resolved-at `now.bowl)
      =/  new-status=order-status
        ?:  =(ruling.cmd %dismissed)  %escrowed
        %resolved
      ?.  ?|  (valid-transition %disputed new-status)
              =(ruling.cmd %dismissed)
          ==
        `this
      =/  updated=order
        u.ord(order-status new-status, escrow updated-esc, updated-at now.bowl)
      =.  orders.state  (~(put by orders.state) thread-id.cmd updated)
      =/  rep-cards=(list card)
        ?.  =(ruling.cmd %dismissed)  ~
        ~  ::  no rep changes on dismissal
      :-  :~  (event-card [%dispute-resolved thread-id.cmd ruling.cmd])
              (event-card [%order-advanced thread-id.cmd %disputed new-status])
          ==
      this
    ::
    ::  WS1: propose-create — validate and approve/reject order creation
    ::
        %propose-create
      ::  check if order already exists
      =/  existing=(unit order)  (~(get by orders.state) thread-id.cmd)
      ?^  existing
        ::  order exists — reject (idempotent create not allowed)
        :-  [(event-card [%proposal-rejected proposal-id.cmd thread-id.cmd %offered 'order already exists'])]~
        this
      ::  validate: buyer != seller
      ?:  =(buyer.cmd seller.cmd)
        :-  [(event-card [%proposal-rejected proposal-id.cmd thread-id.cmd %offered 'buyer cannot be seller'])]~
        this
      ::  validate: amount > 0
      ?:  =(0 amount.cmd)
        :-  [(event-card [%proposal-rejected proposal-id.cmd thread-id.cmd %offered 'zero amount'])]~
        this
      ::  approved — create order atomically
      =/  ord=order
        :*  thread-id.cmd
            listing-id.cmd
            buyer.cmd
            seller.cmd
            offer-id.cmd
            amount.cmd
            currency.cmd
            %offered
            ~
            now.bowl
            now.bowl
        ==
      =.  orders.state  (~(put by orders.state) thread-id.cmd ord)
      :-  :~  (event-card [%order-created ord])
              (event-card [%proposal-approved proposal-id.cmd thread-id.cmd %offered])
          ==
      this
    ::
    ::  WS1: propose-advance — validate transition without mutating, then
    ::  approve+mutate atomically
    ::
        %propose-advance
      =/  ord=(unit order)  (~(get by orders.state) thread-id.cmd)
      ?~  ord
        :-  [(event-card [%proposal-rejected proposal-id.cmd thread-id.cmd to.cmd 'no order exists'])]~
        this
      ::  idempotent: already at target
      ?:  =(order-status.u.ord to.cmd)
        :-  [(event-card [%proposal-approved proposal-id.cmd thread-id.cmd to.cmd])]~
        this
      ?.  (valid-transition order-status.u.ord to.cmd)
        :-  [(event-card [%proposal-rejected proposal-id.cmd thread-id.cmd to.cmd 'invalid transition'])]~
        this
      ::  WS1: approved — advance atomically
      =/  updated=order  u.ord(order-status to.cmd, updated-at now.bowl)
      ::  auto-freeze escrow on dispute
      =?  updated  ?&(=(to.cmd %disputed) ?=(^ escrow.updated))
        =/  frozen-esc=escrow-record  u.escrow.updated(escrow-status %disputed)
        updated(escrow `frozen-esc)
      =.  orders.state  (~(put by orders.state) thread-id.cmd updated)
      ::  WS4: set timeouts as appropriate
      =?  timeouts.state  =(to.cmd %accepted)
        =/  te-id=@uv  (sham [thread-id.cmd %invoice now.bowl])
        (~(put by timeouts.state) te-id [thread-id.cmd %invoice-expiry (add now.bowl ~d7)])
      =?  timeouts.state  =(to.cmd %escrowed)
        =/  te-id=@uv  (sham [thread-id.cmd %escrow now.bowl])
        (~(put by timeouts.state) te-id [thread-id.cmd %escrow-inactivity (add now.bowl ~d14)])
      =?  timeouts.state  =(to.cmd %disputed)
        =/  te-id=@uv  (sham [thread-id.cmd %dispute now.bowl])
        (~(put by timeouts.state) te-id [thread-id.cmd %dispute-deadline (add now.bowl ~d7)])
      =/  base-cards=(list card)
        :~  (event-card [%order-advanced thread-id.cmd order-status.u.ord to.cmd])
            (event-card [%proposal-approved proposal-id.cmd thread-id.cmd to.cmd])
        ==
      =/  dispute-cards=(list card)
        ?.  =(to.cmd %disputed)  ~
        [(event-card [%dispute-filed thread-id.cmd])]~
      =/  rep-cards=(list card)
        ?.  =(to.cmd %completed)  ~
        :-  (event-card [%order-completed thread-id.cmd buyer.u.ord seller.u.ord])
        (attest-completion updated our.bowl now.bowl eny.bowl)
      [(zing ~[base-cards dispute-cards rep-cards]) this]
    ::
        %cancel-stale
      ::  cancel orders stuck in non-terminal states past threshold
      =/  cutoff=@da  (sub now.bowl threshold.cmd)
      =/  stale=(list @uv)
        %+  murn  ~(tap by orders.state)
        |=  [tid=@uv ord=order]
        ::  only cancel non-terminal orders updated before cutoff
        ?.  ?=(?(%offered %accepted %invoiced) order-status.ord)  ~
        ?.  (lth updated-at.ord cutoff)  ~
        `tid
      =/  count=@ud  (lent stale)
      =.  orders.state
        =/  os  orders.state
        =/  sl  stale
        |-
        ?~  sl  os
        =/  ord=(unit order)  (~(get by os) i.sl)
        ?~  ord  $(sl t.sl)
        $(sl t.sl, os (~(put by os) i.sl u.ord(order-status %cancelled, updated-at now.bowl)))
      ?:  =(count 0)  `this
      :-  [(event-card [%stale-cancelled count])]~
      this
    ==
  ==
::
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  (on-peek:def path)
      [%x %orders ~]
    ``noun+!>(~(val by orders.state))
  ::
      [%x %order * ~]
    =/  tid=@uv  (slav %uv i.t.t.path)
    ``noun+!>((~(get by orders.state) tid))
  ::
      [%x %stats ~]
    =/  s
      :*  orders=~(wyt by orders.state)
          listings=~(wyt by listings.state)
          timeouts=~(wyt by timeouts.state)
      ==
    ``noun+!>(s)
  ::
  ::  WS3: check if a transition is valid without mutating
  ::  returns %.y if the advance would be approved
  ::  WS4: fail closed — reject unknown statuses and missing orders
      [%x %check-advance @ @ ~]
    =/  tid=@uv  (slav %uv i.t.t.path)
    =/  to-raw=@tas  (slav %tas i.t.t.t.path)
    ::  reject unknown order-status values
    =/  to-try  (mule |.(;;(order-status to-raw)))
    ?:  ?=(%| -.to-try)
      ``noun+!>(%.n)
    =/  to=order-status  p.to-try
    =/  ord=(unit order)  (~(get by orders.state) tid)
    ?~  ord
      ::  no order yet — approve only for initial %offered transition
      ``noun+!>(=(to %offered))
    ?:  =(order-status.u.ord to)
      ``noun+!>(%.y)  ::  idempotent
    ``noun+!>((valid-transition order-status.u.ord to))
  ==
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+  path  (on-watch:def path)
      [%market-events ~]
    `this
  ==
::
++  on-leave  on-leave:def
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ?+  wire  (on-agent:def wire sign)
      [%rep *]
    `this
  ::
      [%market *]
    `this
  ==
++  on-arvo
  |=  [=wire sign=sign-arvo]
  ^-  (quip card _this)
  ?+  wire  (on-arvo:def wire sign)
      [%market %timeout-poll ~]
    ::  WS4: check expired timeouts
    ?.  ?=([%behn %wake *] sign)  `this
    =/  [expired=(list @uv) cancels=(list @uv)]
      (check-timeouts now.bowl timeouts.state orders.state)
    ::  prune expired timeout entries
    =.  timeouts.state
      =/  ts  timeouts.state
      =/  ex  expired
      |-
      ?~  ex  ts
      $(ex t.ex, ts (~(del by ts) i.ex))
    ::  cancel timed-out orders
    =.  orders.state
      =/  os  orders.state
      =/  cl  cancels
      |-
      ?~  cl  os
      =/  ord=(unit order)  (~(get by os) i.cl)
      ?~  ord  $(cl t.cl)
      $(cl t.cl, os (~(put by os) i.cl u.ord(order-status %cancelled, updated-at now.bowl)))
    ::  re-arm timer
    =/  cancel-events=(list card)
      ?~  cancels  ~
      [(event-card [%stale-cancelled (lent cancels)])]~
    =/  timer-card=card  [%pass /market/timeout-poll %arvo %b %wait (add now.bowl ~m5)]
    :-  (snoc cancel-events timer-card)
    this
  ==
++  on-fail   on-fail:def
--
