|%
+$  relay-key    @ux
+$  header-box   @ux
+$  payload-box  @ux
+$  reply-token  @ux
+$  header-layer
  $:  next=(unit ship)
      inner=(unit header-box)
      body-key=(unit relay-key)
      delay=(unit @dr)
  ==
--
