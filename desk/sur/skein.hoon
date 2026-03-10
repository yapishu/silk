/-  *skein-crypto
|%
+$  app-id  term
+$  relay-id  @t
::
+$  endpoint
  $:  ship=@p
      app=app-id
  ==
::
+$  relay-descriptor
  $:  relay=relay-id
      ship=@p
      key=(unit relay-key)
      weight=@ud
      default-delay=(unit @dr)
      expiry=(unit @da)
  ==
::
+$  route-hop
  $:  ship=@p
      relay=relay-id
      key=(unit relay-key)
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
  $:  token=reply-token
      header=header-box
      body=payload-box
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
      [%clear-seen ~]
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
+$  relay-step
  $:  cell-id=@uv
      remaining=(list ship)
  ==
::
+$  relay-cell
  $:  cell-id=@uv
      id=@ud
      origin=endpoint
      target=endpoint
      sent-at=@da
      remaining=(list ship)
      header=header-box
      body=payload-box
      opts=send-options
      expiry=(unit @da)
  ==
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
--
