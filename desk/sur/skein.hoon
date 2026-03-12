/-  *skein-crypto
|%
+$  app-id  term
+$  relay-id  @t
+$  channel-id  @tas
::
+$  endpoint
  $:  ship=@p
      app=app-id
  ==
::
+$  relay-descriptor
  $:  relay=relay-id
      ship=@p
      key=relay-key
      weight=@ud
      default-delay=(unit @dr)
      expiry=(unit @da)
  ==
::
+$  route-hop
  $:  ship=@p
      relay=relay-id
      key=relay-key
      delay=(unit @dr)
  ==
::
+$  route
  $:  route-id=@uv
      hops=(list route-hop)
  ==
::
+$  route-log
  $:  cell-id=@uv
      route-id=@uv
      target=endpoint
      hops=(list ship)
      selected-at=@da
  ==
::
+$  reply-block
  $:  token=reply-token       ::  derive body key: (shaz (jam [%reply-body token]))
      cell-id=@uv             ::  cell-id baked into header layers
      first-hop=ship          ::  where recipient sends the reply cell
      header=header-box       ::  pre-built onion header (route back to sender)
      expiry=(unit @da)
  ==
::
+$  send-options
  $:  route=(unit route)
      reply-blocks=(list reply-block)
      ttl=(unit @dr)
  ==
::
+$  send-request
  $:  from=app-id
      to=endpoint
      payload=*
      opts=send-options
  ==
::
+$  admin-action
  $%  [%bind app=app-id]
      [%unbind app=app-id]
      [%clear app=app-id]
      [%put-relay descriptor=relay-descriptor]
      [%drop-relay relay=relay-id]
      [%discover-relay ship=@p]
      [%clear-seen ~]
      [%join-channel channel=channel-id app=app-id]
      [%leave-channel channel=channel-id]
      [%set-min-hops n=@ud]
      [%add-seed ship=@p]
      [%drop-seed ship=@p]
      [%set-adaptive-hops on=?]
      [%build-reply-block ~]
      [%trust-relay relay=relay-id]
      [%untrust-relay relay=relay-id]
  ==
::
+$  envelope
  $:  id=@ud
      origin=endpoint
      target=endpoint
      sent-at=@da
      payload=*
      opts=send-options
  ==
::
::  blind relay cell — no cleartext origin/target/route
::
+$  relay-cell
  $:  cell-id=@uv
      header=header-box
      body=payload-box
      expiry=(unit @da)
  ==
::
::  replay detection by cell-id only
::
+$  relay-step  @uv
::
+$  event
  $%  [%message =envelope]
      [%bound app=app-id]
      [%unbound app=app-id]
      [%cleared app=app-id]
      [%relay-added descriptor=relay-descriptor]
      [%relay-removed relay=relay-id]
      [%sent cell-id=@uv to=endpoint]
      [%route-selected cell-id=@uv route=route]
      [%received cell-id=@uv from=ship]
      [%forwarded cell-id=@uv to=ship]
      [%delivered cell-id=@uv app=app-id]
      [%replay-cleared ~]
      [%dropped cell-id=@uv reason=@t]
      [%channel-joined channel=channel-id]
      [%channel-left channel=channel-id]
      [%channel-peer channel=channel-id ship=@p joined=?]
      [%degraded-route cell-id=@uv wanted=@ud got=@ud]
      [%seed-added ship=@p]
      [%seed-removed ship=@p]
      [%reply-block-built =reply-block]
      [%relay-trusted relay=relay-id]
      [%relay-untrusted relay=relay-id]
      [%relay-expired relay=relay-id]
  ==
::
+$  app-view
  $:  bound=?
      queued=(list envelope)
  ==
::
+$  directory-view
  $:  relays=(list relay-descriptor)
      recent-routes=(list route-log)
  ==
::
+$  channel-update
  $%  [%join channel=channel-id ship=@p]
      [%leave channel=channel-id ship=@p]
      [%members channel=channel-id ships=(list @p)]
  ==
--
