::  %silk-rep: pseudonym reputation and attestation agent
::
::  manages attestations issued and received for pseudonyms.
::  computes aggregate reputation scores per pseudonym.
::
/-  *silk
/+  dbug, verb, default-agent
|%
+$  state-0
  $:  %0
      issued=(map attest-id attestation)
      received=(map attest-id attestation)
      scores=(map nym-id @ud)
  ==
::
+$  current-state  state-0
+$  card  card:agent:gall
::
++  event-card
  |=  ev=rep-event
  ^-  card
  [%give %fact [/rep-events]~ %noun !>(ev)]
::
++  recompute-score
  |=  [subject=nym-id received=(map attest-id attestation)]
  ^-  @ud
  =/  total=@ud  0
  =/  count=@ud  0
  =/  atts=(list attestation)  ~(val by received)
  |-
  ?~  atts
    ?:(=(count 0) 0 (div total count))
  ?.  =(subject.i.atts subject)
    $(atts t.atts)
  $(atts t.atts, total (add total score.i.atts), count +(count))
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
  =.  state  !<(current-state old)
  `this
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?+  mark  (on-poke:def mark vase)
      %noun
    ?>  =(our src):bowl
    =/  cmd  !<(rep-command vase)
    ?-  -.cmd
        %issue
      =/  att=attestation  attestation.cmd
      =.  issued.state  (~(put by issued.state) id.att att)
      :-  [(event-card [%issued att])]~
      this
    ::
        %revoke
      =.  issued.state  (~(del by issued.state) id.cmd)
      :-  [(event-card [%revoked id.cmd])]~
      this
    ::
        %import
      =/  att=attestation  attestation.cmd
      =.  received.state  (~(put by received.state) id.att att)
      =/  new-score=@ud  (recompute-score subject.att received.state)
      =.  scores.state  (~(put by scores.state) subject.att new-score)
      :-  :~  (event-card [%imported att])
              (event-card [%score-updated subject.att new-score])
          ==
      this
    ==
  ==
::
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  (on-peek:def path)
      [%x %scores ~]
    ``noun+!>(~(tap by scores.state))
  ::
      [%x %score * ~]
    =/  nid=@uv  (slav %uv i.t.t.path)
    ``noun+!>((~(get by scores.state) nid))
  ::
      [%x %issued ~]
    ``noun+!>(~(val by issued.state))
  ::
      [%x %received ~]
    ``noun+!>(~(val by received.state))
  ::
      [%x %stats ~]
    =/  s
      :*  issued=~(wyt by issued.state)
          received=~(wyt by received.state)
          scores=~(wyt by scores.state)
      ==
    ``noun+!>(s)
  ==
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+  path  (on-watch:def path)
      [%rep-events ~]
    `this
  ==
::
++  on-leave  on-leave:def
++  on-agent  on-agent:def
++  on-arvo   on-arvo:def
++  on-fail   on-fail:def
--
