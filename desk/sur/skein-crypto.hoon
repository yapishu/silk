|%
+$  relay-key    @ux
+$  header-box   @ux
+$  payload-box  @ux
+$  reply-token  @ux
+$  header-layer
  $:  next=(unit ship)
      next-cell-id=(unit @uv)
      inner=(unit header-box)
      body-key=(unit relay-key)
      rng=(unit @ux)
      delay=(unit @dr)
      body-mac=(unit @ux)        ::  MAC of cell body for integrity check
  ==
--
