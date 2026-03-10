::  %silk-zenith: payment adapter for Zenith settlement
::
::  manages payment addresses, generates invoices,
::  verifies payment proofs, and coordinates with
::  silk-market for escrow state.
::
::  supports both local %zenith agent and external wallets.
::
/-  *silk
/+  dbug, verb, default-agent
|%
::
::  payment address: rotated independently of transport identity
::
+$  pay-address
  $:  address=@t
      nym-id=nym-id
      currency=@tas
      created-at=@da
      used=?
  ==
::
::  wallet mode: local zenith agent or external
::
+$  wallet-mode
  $?  %local     ::  use local %zenith agent
      %external  ::  manual external wallet
  ==
::
::  payment record
::
+$  payment-record
  $:  invoice-id=invoice-id
      thread-id=@uv
      amount=@ud
      currency=@tas
      address=@t
      tx-hash=(unit @ux)
      =payment-status
      created-at=@da
      confirmed-at=(unit @da)
  ==
::
+$  payment-status
  $?  %pending      ::  invoice issued, awaiting payment
      %submitted    ::  buyer claims paid
      %confirmed    ::  payment verified
      %failed       ::  payment verification failed
  ==
::
+$  zenith-command
  $%  ::  address management
      [%add-address address=@t nym-id=nym-id currency=@tas]
      [%set-mode =wallet-mode]
      ::  invoice flow
      [%create-invoice thread-id=@uv amount=@ud currency=@tas seller-nym=nym-id]
      [%record-payment invoice-id=invoice-id tx-hash=@ux]
      [%confirm-payment invoice-id=invoice-id]
      [%fail-payment invoice-id=invoice-id reason=@t]
  ==
::
+$  zenith-event
  $%  [%address-added address=@t nym-id=nym-id]
      [%mode-set =wallet-mode]
      [%invoice-created =payment-record]
      [%payment-recorded invoice-id=invoice-id tx-hash=@ux]
      [%payment-confirmed invoice-id=invoice-id thread-id=@uv]
      [%payment-failed invoice-id=invoice-id reason=@t]
  ==
::
+$  state-0
  $:  %0
      mode=wallet-mode
      addresses=(map @t pay-address)
      payments=(map invoice-id payment-record)
      address-pool=(map nym-id (list @t))
  ==
::
+$  current-state  state-0
+$  card  card:agent:gall
::
++  event-card
  |=  ev=zenith-event
  ^-  card
  [%give %fact [/zenith-events]~ %noun !>(ev)]
::
::  pick a fresh address for a nym, mark it used
::
++  pick-address
  |=  [nym=nym-id pool=(map nym-id (list @t)) addresses=(map @t pay-address)]
  ^-  (unit [address=@t pool=(map nym-id (list @t)) addresses=(map @t pay-address)])
  =/  avail=(list @t)  (~(gut by pool) nym ~)
  |-
  ?~  avail  ~
  =/  pa=(unit pay-address)  (~(get by addresses) i.avail)
  ?~  pa  $(avail t.avail)
  ?:  used.u.pa  $(avail t.avail)
  =/  updated=pay-address  u.pa(used %.y)
  =/  new-addrs  (~(put by addresses) i.avail updated)
  =/  new-pool  (~(put by pool) nym t.avail)
  `[i.avail new-pool new-addrs]
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
  =.  mode.state  %external
  `this
::
++  on-save
  !>(state)
::
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  =.  state  !<(current-state old)
  `this
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?+  mark  (on-poke:def mark vase)
      %noun
    ?>  =(our src):bowl
    =/  cmd  !<(zenith-command vase)
    ?-  -.cmd
        %add-address
      =/  pa=pay-address  [address.cmd nym-id.cmd currency.cmd now.bowl %.n]
      =.  addresses.state  (~(put by addresses.state) address.cmd pa)
      =/  existing=(list @t)  (~(gut by address-pool.state) nym-id.cmd ~)
      =.  address-pool.state  (~(put by address-pool.state) nym-id.cmd [address.cmd existing])
      :-  [(event-card [%address-added address.cmd nym-id.cmd])]~
      this
    ::
        %set-mode
      =.  mode.state  wallet-mode.cmd
      :-  [(event-card [%mode-set wallet-mode.cmd])]~
      this
    ::
        %create-invoice
      ::  pick a fresh address for this seller nym
      =/  picked
        (pick-address seller-nym.cmd address-pool.state addresses.state)
      =/  addr=@t
        ?~  picked  'no-address-available'
        address.u.picked
      =?  address-pool.state  ?=(^ picked)  pool.u.picked
      =?  addresses.state  ?=(^ picked)  addresses.u.picked
      =/  inv-id=invoice-id  (sham [thread-id.cmd now.bowl eny.bowl])
      =/  rec=payment-record
        [inv-id thread-id.cmd amount.cmd currency.cmd addr ~ %pending now.bowl ~]
      =.  payments.state  (~(put by payments.state) inv-id rec)
      :-  [(event-card [%invoice-created rec])]~
      this
    ::
        %record-payment
      =/  rec=(unit payment-record)  (~(get by payments.state) invoice-id.cmd)
      ?~  rec  `this
      =/  updated=payment-record
        u.rec(tx-hash `tx-hash.cmd, payment-status %submitted)
      =.  payments.state  (~(put by payments.state) invoice-id.cmd updated)
      :-  [(event-card [%payment-recorded invoice-id.cmd tx-hash.cmd])]~
      this
    ::
        %confirm-payment
      =/  rec=(unit payment-record)  (~(get by payments.state) invoice-id.cmd)
      ?~  rec  `this
      =/  updated=payment-record
        u.rec(payment-status %confirmed, confirmed-at `now.bowl)
      =.  payments.state  (~(put by payments.state) invoice-id.cmd updated)
      ::  notify silk-market to advance escrow
      =/  market-card=card
        [%pass /zenith/escrow %agent [our.bowl %silk-market] %poke %noun !>([%set-escrow thread-id.u.rec (need tx-hash.updated)])]
      :-  :~  (event-card [%payment-confirmed invoice-id.cmd thread-id.u.rec])
              market-card
          ==
      this
    ::
        %fail-payment
      =/  rec=(unit payment-record)  (~(get by payments.state) invoice-id.cmd)
      ?~  rec  `this
      =/  updated=payment-record  u.rec(payment-status %failed)
      =.  payments.state  (~(put by payments.state) invoice-id.cmd updated)
      :-  [(event-card [%payment-failed invoice-id.cmd reason.cmd])]~
      this
    ==
  ==
::
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  (on-peek:def path)
      [%x %payments ~]
    ``noun+!>(~(val by payments.state))
  ::
      [%x %payment * ~]
    =/  inv-id=@uv  (slav %uv i.t.t.path)
    ``noun+!>((~(get by payments.state) inv-id))
  ::
      [%x %addresses ~]
    ``noun+!>(~(val by addresses.state))
  ::
      [%x %mode ~]
    ``noun+!>(mode.state)
  ::
      [%x %stats ~]
    =/  s
      :*  mode=mode.state
          addresses=~(wyt by addresses.state)
          payments=~(wyt by payments.state)
          pools=~(wyt by address-pool.state)
      ==
    ``noun+!>(s)
  ==
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+  path  (on-watch:def path)
      [%zenith-events ~]
    `this
  ==
::
++  on-leave  on-leave:def
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ?+  wire  (on-agent:def wire sign)
      [%zenith *]
    `this
  ==
++  on-arvo   on-arvo:def
++  on-fail   on-fail:def
--
