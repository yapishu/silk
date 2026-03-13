::  %silk-market: marketplace order state machine
::
::  manages the lifecycle of orders: listing → offer → accept →
::  invoice → payment → fulfillment → completion.
::  enforces valid state transitions.
::  triggers reputation attestations on completion.
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
  ==
::
+$  state-1
  $:  %1
      orders=(map @uv order)
      listings=(map listing-id listing)
  ==
::
+$  state-0
  $:  %0
      orders=(map @uv order)
      listings=(map listing-id listing)
  ==
::
+$  current-state  state-1
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
  `this
::
++  on-save
  !>(state)
::
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  =/  ver  ;;(@ud -.q.old)
  =.  state
    ?:  =(ver 1)  !<(state-1 old)
    ?:  =(ver 0)
      =/  s0  !<(state-0 old)
      [%1 orders.s0 listings.s0]
    *state-1
  `this
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
        [(event-card [%dispute-filed thread-id.cmd])]~
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
          %split        %released   ::  split treated as release for now
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
      ==
    ``noun+!>(s)
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
  ==
++  on-arvo   on-arvo:def
++  on-fail   on-fail:def
--
