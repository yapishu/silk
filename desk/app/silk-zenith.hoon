::  %silk-zenith: payment adapter for Zenith settlement
::
::  thin adapter that delegates wallet operations to the
::  real %zenith agent on the %zenith desk.  keeps payment
::  records, addresses, and address-pool locally (silk-specific).
::
::  WS4: removed local accounts, key derivation, khan threads.
::  all wallet ops are poke-forwards to [our %zenith].
::
::  poke: %add-account, %send-to-addr, %create-invoice,
::        %record-payment, %confirm-payment, %fail-payment,
::        %broadcast-escrow, %query-escrow-account, %set-mode,
::        %add-address (legacy)
::  scry: /x/payments, /x/addresses, /x/mode, /x/stats,
::        /x/account/<name>/noun, /x/accounts/noun
::  events: %invoice-created, %payment-submitted,
::          %payment-confirmed, %payment-failed,
::          %address-added, %mode-set,
::          %escrow-broadcast, %escrow-broadcast-fail
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
  $%  ::  WS4: account management — forwarded to %zenith
      [%add-account name=@t key=@ux]
      [%send-to-addr from=@t to=@t amount=@ud denom=@t]
      ::  legacy address management
      [%add-address address=@t nym-id=nym-id currency=@tas]
      [%set-mode =wallet-mode]
      ::  invoice flow
      [%create-invoice thread-id=@uv amount=@ud currency=@tas seller-nym=nym-id]
      [%record-payment invoice-id=invoice-id tx-hash=@ux]
      [%confirm-payment invoice-id=invoice-id]
      [%fail-payment invoice-id=invoice-id reason=@t]
      ::  escrow tx broadcast
      [%broadcast-escrow thread-id=@uv tx-hex=@t]
      ::  account query for multisig
      [%query-escrow-account thread-id=@uv address=@t]
  ==
::
+$  zenith-event
  $%  [%address-added address=@t nym-id=nym-id]
      [%mode-set =wallet-mode]
      [%invoice-created =payment-record]
      [%payment-submitted invoice-id=invoice-id tx-hash=@ux]
      [%payment-recorded invoice-id=invoice-id tx-hash=@ux]
      [%payment-confirmed invoice-id=invoice-id thread-id=@uv]
      [%payment-failed invoice-id=invoice-id reason=@t]
      ::  account events
      [%account-created name=@t address=@t]
      [%payment-sent from=@t to=@t amount=@ud tx-hash=@t]
      ::  escrow tx events
      [%escrow-broadcast thread-id=@uv tx-hash=@t]
      [%escrow-broadcast-fail thread-id=@uv reason=@t]
  ==
::
+$  state-0
  $:  %0
      mode=wallet-mode
      addresses=(map @t pay-address)
      payments=(map invoice-id payment-record)
      address-pool=(map nym-id (list @t))
      pending-invoices=(map @t [thread-id=@uv amount=@ud currency=@tas seller-nym=nym-id])
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
  =/  load-result  (mule |.(!<(state-0 old)))
  =.  state  ?:(?=(%& -.load-result) p.load-result *state-0)
  `this
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?+  mark  (on-poke:def mark vase)
      %noun
    ?>  =(our src):bowl
    =/  cmd=zenith-command  ;;(zenith-command q.vase)
    ?-  -.cmd
    ::
    ::  WS4: %add-account — forward to %zenith agent
    ::
        %add-account
      =/  zen-poke=card
        [%pass /zenith/add-account/[name.cmd] %agent [our.bowl %zenith] %poke %add-account !>([name.cmd key.cmd])]
      ::  also register as a pay-address for compatibility
      =/  pa=pay-address  ['' *nym-id %zen now.bowl %.n]
      :-  [zen-poke]~
      this
    ::
    ::  WS4: %send-to-addr — forward to %zenith agent
    ::
        %send-to-addr
      ~&  [%silk-zenith %send-to-addr %forwarding-to-zenith from.cmd %to to.cmd %amount amount.cmd %denom denom.cmd]
      =/  zen-poke=card
        [%pass /zenith/send-tx/[from.cmd] %agent [our.bowl %zenith] %poke %send-to-addr !>([from.cmd to.cmd amount.cmd denom.cmd])]
      =/  tx-hash=@t  (scot %ux (sham [from.cmd to.cmd amount.cmd now.bowl]))
      :-  :~  zen-poke
              (event-card [%payment-sent from.cmd to.cmd amount.cmd tx-hash])
          ==
      this
    ::
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
    ::  WS4: %create-invoice — poke %zenith %add-account for key gen,
    ::  then on poke-ack scry address from %zenith
    ::
        %create-invoice
      ::  pick a fresh address for this seller nym
      =/  picked
        (pick-address seller-nym.cmd address-pool.state addresses.state)
      =/  inv-id=invoice-id  (sham [thread-id.cmd now.bowl eny.bowl])
      ?^  picked
        ::  use pre-loaded pool address
        =.  address-pool.state  pool.u.picked
        =.  addresses.state  addresses.u.picked
        =/  rec=payment-record
          [inv-id thread-id.cmd amount.cmd currency.cmd address.u.picked ~ %pending now.bowl ~]
        =.  payments.state  (~(put by payments.state) inv-id rec)
        :-  [(event-card [%invoice-created rec])]~
        this
      ::  no pool address: generate a key and poke %zenith to create account
      =/  priv-key=@ux  `@ux`(shax (jam [inv-id now.bowl eny.bowl]))
      =/  acc-name=@t  (scot %uv inv-id)
      ::  WS4: store pending invoice, forward key to %zenith
      =.  pending-invoices.state
        (~(put by pending-invoices.state) acc-name [thread-id.cmd amount.cmd currency.cmd seller-nym.cmd])
      =/  zen-poke=card
        [%pass /zenith/create-invoice/[acc-name] %agent [our.bowl %zenith] %poke %add-account !>([acc-name priv-key])]
      :-  [zen-poke]~
      this
    ::
        %record-payment
      =/  rec=(unit payment-record)  (~(get by payments.state) invoice-id.cmd)
      ?~  rec  `this
      =/  updated=payment-record
        u.rec(tx-hash `tx-hash.cmd, payment-status %submitted)
      =.  payments.state  (~(put by payments.state) invoice-id.cmd updated)
      :-  :~  (event-card [%payment-submitted invoice-id.cmd tx-hash.cmd])
              (event-card [%payment-recorded invoice-id.cmd tx-hash.cmd])
          ==
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
    ::
    ::  WS4: %broadcast-escrow — forward to %zenith via %broadcast-raw-tx
    ::
        %broadcast-escrow
      ~&  [%silk-zenith %broadcasting-escrow-tx thread-id.cmd]
      =/  zen-poke=card
        [%pass /zenith/broadcast/[(scot %uv thread-id.cmd)] %agent [our.bowl %zenith] %poke %broadcast-raw-tx !>(tx-hex.cmd)]
      :-  :~  zen-poke
              (event-card [%escrow-broadcast thread-id.cmd tx-hex.cmd])
          ==
      this
    ::
    ::  WS4: %query-escrow-account — use %zenith khan thread to query chain
    ::  (queries chain REST API for account number/sequence by address)
    ::
        %query-escrow-account
      ~&  [%silk-zenith %querying-account thread-id.cmd address.cmd]
      =/  query-card=card
        [%pass /zenith/query-account/[(scot %uv thread-id.cmd)] %arvo %k %fard %zenith %query-account %noun !>(address.cmd)]
      :-  [query-card]~
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
  ::  WS4: /x/accounts — scry through to %zenith
      [%x %accounts %noun ~]
    =/  result
      (mule |.(.^(* %gx /(scot %p our.bowl)/zenith/(scot %da now.bowl)/accounts/noun)))
    ?:  ?=(%| -.result)  ``noun+!>(~)
    ``noun+!>(p.result)
  ::
      [%x %accounts ~]
    =/  result
      (mule |.(.^(* %gx /(scot %p our.bowl)/zenith/(scot %da now.bowl)/accounts/noun)))
    ?:  ?=(%| -.result)  ``noun+!>(~)
    ``noun+!>(p.result)
  ::
  ::  WS4: /x/account/<name> — scry through to %zenith
      [%x %account @ %noun ~]
    =/  name=@t  i.t.t.path
    =/  result
      (mule |.(.^(* %gx /(scot %p our.bowl)/zenith/(scot %da now.bowl)/account/[name]/noun)))
    ?:  ?=(%| -.result)  ``noun+!>(~)
    ``noun+!>(p.result)
  ::
      [%x %account @ ~]
    =/  name=@t  i.t.t.path
    =/  result
      (mule |.(.^(* %gx /(scot %p our.bowl)/zenith/(scot %da now.bowl)/account/[name]/noun)))
    ?:  ?=(%| -.result)  ``noun+!>(~)
    ``noun+!>(p.result)
  ::
      [%x %stats ~]
    =/  s
      :*  mode=mode.state
          addresses=~(wyt by addresses.state)
          payments=~(wyt by payments.state)
          pools=~(wyt by address-pool.state)
          pending-invoices=~(wyt by pending-invoices.state)
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
  ::
  ::  WS4: %add-account poke-ack from %zenith
  ::
      [%zenith %add-account @ ~]
    ?.  ?=(%poke-ack -.sign)  `this
    =/  name=@t  i.t.t.wire
    ?^  p.sign
      ~&  [%silk-zenith %add-account-failed name]
      ((slog u.p.sign) `this)
    ::  scry %zenith for the account address
    =/  result
      (mule |.(.^(* %gx /(scot %p our.bowl)/zenith/(scot %da now.bowl)/account/[name]/noun)))
    ?:  ?=(%| -.result)
      ~&  [%silk-zenith %add-account-scry-failed name]
      `this
    =/  acc-try  (mule |.(;;([addr=@t pub-key=@ux priv-key=@ux acc-num=@ud seq-num=@ud] p.result)))
    ?:  ?=(%| -.acc-try)
      ~&  [%silk-zenith %add-account-parse-failed name]
      `this
    =/  addr=@t  addr.p.acc-try
    ::  register as pay-address
    =/  pa=pay-address  [addr *nym-id %zen now.bowl %.n]
    =.  addresses.state  (~(put by addresses.state) addr pa)
    :-  [(event-card [%account-created name addr])]~
    this
  ::
  ::  WS4: create-invoice poke-ack — %zenith created account, now scry address
  ::
      [%zenith %create-invoice @ ~]
    ?.  ?=(%poke-ack -.sign)  `this
    =/  acc-name=@t  i.t.t.wire
    ?^  p.sign
      ~&  [%silk-zenith %create-invoice-account-failed acc-name]
      =.  pending-invoices.state  (~(del by pending-invoices.state) acc-name)
      ((slog u.p.sign) `this)
    ::  look up pending invoice
    =/  pi=(unit [thread-id=@uv amount=@ud currency=@tas seller-nym=nym-id])
      (~(get by pending-invoices.state) acc-name)
    ?~  pi
      ~&  [%silk-zenith %create-invoice-no-pending acc-name]
      `this
    =.  pending-invoices.state  (~(del by pending-invoices.state) acc-name)
    ::  scry %zenith for the address
    =/  result
      (mule |.(.^(* %gx /(scot %p our.bowl)/zenith/(scot %da now.bowl)/account/[acc-name]/noun)))
    ?:  ?=(%| -.result)
      ~&  [%silk-zenith %create-invoice-scry-failed acc-name]
      `this
    =/  acc-try  (mule |.(;;([addr=@t pub-key=@ux priv-key=@ux acc-num=@ud seq-num=@ud] p.result)))
    ?:  ?=(%| -.acc-try)
      ~&  [%silk-zenith %create-invoice-parse-failed acc-name]
      `this
    =/  addr=@t  addr.p.acc-try
    ::  create payment record with the %zenith-generated address
    =/  inv-id=invoice-id  (slav %uv acc-name)
    =/  rec=payment-record
      [inv-id thread-id.u.pi amount.u.pi currency.u.pi addr ~ %pending now.bowl ~]
    =.  payments.state  (~(put by payments.state) inv-id rec)
    =/  pa=pay-address  [addr *nym-id %zen now.bowl %.n]
    =.  addresses.state  (~(put by addresses.state) addr pa)
    :-  :~  (event-card [%invoice-created rec])
            (event-card [%account-created acc-name addr])
        ==
    this
  ::
  ::  WS4: send-to-addr poke-ack from %zenith
  ::
      [%zenith %send-tx @ ~]
    ?.  ?=(%poke-ack -.sign)  `this
    =/  from=@t  i.t.t.wire
    ?^  p.sign
      ~&  [%silk-zenith %send-tx-failed from]
      ((slog u.p.sign) `this)
    ~&  [%silk-zenith %send-tx-ok from]
    `this
  ::
  ::  WS4: broadcast-raw-tx poke-ack from %zenith
  ::
      [%zenith %broadcast @ ~]
    ?.  ?=(%poke-ack -.sign)  `this
    =/  tid=@uv  (slav %uv i.t.t.wire)
    ?^  p.sign
      ~&  [%silk-zenith %broadcast-failed tid]
      :-  :~  [%pass /zenith/broadcast-fail %agent [our.bowl %silk-core] %poke %noun !>([%escrow-broadcast-fail tid])]
          ==
      this
    ~&  [%silk-zenith %broadcast-ok tid]
    ::  notify silk-core to start confirmation polling
    =/  poke-card=card
      [%pass /zenith/broadcast-ok %agent [our.bowl %silk-core] %poke %noun !>([%escrow-broadcast-ok tid 'broadcast-ok'])]
    :-  [poke-card]~
    this
  ::
      [%zenith *]
    `this
  ==
++  on-arvo
  |=  [=wire sign=sign-arvo]
  ^-  (quip card _this)
  ?+  wire  (on-arvo:def wire sign)
      [%zenith %query-account @ ~]
    =/  tid=@uv  (slav %uv i.t.t.wire)
    ?.  ?=([%khan %arow *] sign)  `this
    =/  res=(each cage tang)  +>.sign
    ?:  ?=(%| -.res)
      ~&  [%silk-zenith %query-account-failed tid]
      `this
    =/  result  !<([acc-num=@ud seq-num=@ud] q.p.res)
    ~&  [%silk-zenith %account-info tid acc-num.result seq-num.result]
    =/  poke-card=card
      [%pass /zenith/set-account %agent [our.bowl %silk-core] %poke %noun !>([%set-escrow-account tid acc-num.result seq-num.result])]
    :-  [poke-card]~
    this
  ==
++  on-fail   on-fail:def
--
