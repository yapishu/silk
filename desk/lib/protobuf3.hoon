/-  *protobuf3

|%
+|  %construction
++  mk-message-type
  |=  [name=@t url=(unit @t) field-defs=(list [@ud field-def])]
  ^-  message-type
  :-  name
  :-  url
  %-  ~(gas by *(map @ud field-def))
  field-defs
++  mk-message-bare
  |=  fields=(list [@ud field-bare])
  ^-  message-bare
  %-  ~(gas by *message-bare)
  fields
++  mk-enum
  |=  [name=@t values=(list [@ud @t])]
  ^-  enum
  :-  name
  (~(gas ju *(jug @ud @t)) values)
::
+|  %conversions
++  make-full-message
  |=  [bare=message-bare type=message-type]
  ^-  message-full
  *message-full
++  strip-message
  |=  [full=message-full]
  ^-  message-bare
  *message-bare
:: deterministic ADR 027 serialization
:: https://docs.cosmos.network/v0.53/build/architecture/adr-027-deterministic-protobuf-serialization
+|  %serialization
++  encode-message
  |=  msg=message-bare
  ^-  @tx
  =/  sorted=(list [i=@ud f=field-bare])
    %+  sort  ~(tap by msg)
    |=  [a=[p=@ud q=*] b=[p=@ud q=*]]
    (lth p.a p.b)
  (encode-fields sorted)
++  encode-fields
  |=  fields=(list [i=@ud f=field-bare])
  ^-  @tx
  %+  roll  fields
  |=  [[i=@ud f=field-bare] buf=@tx]
  ?~  wyr=(encode-field i f)
    buf
  (cat 3 buf u.wyr)  :: this puts the next wire on the end of the buffer
++  encode-field
  |=  [ind=@ud fel=field-bare]
  ^-  (unit @tx)
  ::  skip default values
  ::  ~ is the default in ALMOST every case because hoon is absurd
  ?:  ?=([%repeated * ~] fel)  ~
  ?:  ?=([%bool %.n] fel)  ~
  ?:  &(!?=(%bool -.fel) ?=(~ +.fel))  ~
  %-  some
  ?:  ?=([%repeated unpackable *] fel)
    %-  encode-fields
    ?-  type.fel
      %string
        %+  turn  values.fel
        |=  value=@t
        ^-  [@ud field-bare]
        [ind [type.fel value]]
      %bytes
        %+  turn  values.fel
        |=  [len=(unit @ud) value=@]
        ^-  [@ud field-bare]
        [ind [type.fel len value]]
      %embedded
        %+  turn  values.fel
        |=  value=message-bare
        ^-  [@ud field-bare]
        [ind [type.fel value]]
    ==
  =/  typ  (get-wire-type fel)
  =/  tag  (encode-tag ind typ)
  =/  val  (encode-value fel)
  (cat 3 tag val)
++  encode-tag
  |=  [ind=@ud typ=wire-type]
  ^-  @tx
  ?>  (lth ind (bex 29))  :: tag is 32 bits, but 3 are for the wire type
  %-  encode-varint
  (add (lsh [0 3] ind) typ)
++  get-wire-type  :: returns ~ if is default
  |=  fel=field-bare
  ^-  wire-type
  ?-  -.fel
    ?(%int32 %int64 %uint32 %uint64 %sint32 %sint64 %bool %enum)
      varint
    ?(%fixed64 %sfixed64 %double)
      i64
    ?(%string %bytes %embedded %repeated)
      len
    ?(%fixed32 %sfixed32 %float)
      i32
  ==
++  encode-value
  |=  fel=field-bare
  ^-  @tx
  ?<  ?&  ?=(?(%int32 %uint32 %sint32 %fixed32 %sfixed32 %float) -.fel)
          (gte `@`+.fel (bex 32))
      ==
  ?<  ?&  ?=(?(%int64 %uint64 %sint64 %fixed64 %sfixed64 %double %enum) -.fel)
          (gte `@`+.fel (bex 64))
      ==
  ?-  -.fel
    ?(%uint32 %uint64 %enum)
      (encode-varint value.fel)
    ?(%int32 %int64)
      =/  old  (old:si value.fel)
      ?:  -.old
        (encode-varint +.old)
      =/  bytes  ?:(?=(%int32 -.fel) 4 8)
      (encode-varint (twos-comp +.old bytes))
    ?(%sint32 %sint64)
      (encode-varint `@ud`value.fel)  :: already zigzagged
    %bool
      (to-hex-min `@ux`!value.fel 2)
    %fixed32  :: unsigned little-endian (normal) fixed size
      (to-hex-min value.fel 8)
    %fixed64  :: unsigned little-endian (normal) fixed size
      (to-hex-min value.fel 16)
    ?(%sfixed32 %sfixed64)  :: signed (two's complement) little-endian (normal) fixed size
      =/  bytes  ?:(?=(%sfixed32 -.fel) 4 8)
      =/  len  (mul 2 bytes)
      =/  old  (old:si value.fel)
      ?:  -.old
        (to-hex-min +.old len)
      (to-hex-min (twos-comp +.old bytes) len)
    ::
    :: floating point encodings aren't really supported
    :: because I didn't see any info about what the actual
    :: encoding is supposed to be. So here's the @r data
    :: of the right size, if that's helpful
    %float
      (to-hex-min value.fel 8)
    %double
      (to-hex-min value.fel 16)
    ?(%string %bytes)
      =/  byt-len
        ?:  ?=(%string -.fel)
          (met 3 value.fel)
        ?~  len.fel
          (met 3 value.fel)
        u.len.fel
      =/  val
        ?:  ?=(%string -.fel)  (swp 3 value.fel)  value.fel
      %^  cat  3
        (encode-varint byt-len)
      (to-hex-min val (mul 2 byt-len))
    %embedded
      (encode-len (encode-message msg.fel))
    %repeated
      ?<  ?=(unpackable type.fel)
      %-  encode-len
      %+  roll  values.fel
      |=  [value=@ buf=@tx]
      ^-  @tx
      %^  cat  3  buf
      (encode-value ;;(field-bare [type.fel value]))
  ==
++  encode-varint
  |=  int=@ud
  ^-  @tx  %-  to-hex
  =/  bytes  (rip [0 7] int)
  =/  continued
    |-  ^-  (list @)
    ?~  bytes  ~
    ?~  t.bytes
      bytes
    ::  flip continuation bit on all but last
    :-  (con 128 i.bytes)
    $(bytes t.bytes)
  (rep 3 (flop continued))
++  encode-len
  |=  dat=@tx
  ^-  @tx
  =/  byt-len  (met 4 dat)  :: each "byte" is two bytes bc it's a cord
  (cat 3 (encode-varint byt-len) dat)
++  sd-to-twos-comp
  |=  [int=@sd bytes=@ud]
  (twos-comp (abs:si int) bytes)
++  twos-comp
  |=  [int=@ud bytes=@ud]
  +((not 3 bytes int))
++  to-hex
  |=  hol=@
  ^-  @tx
  =/  min  (mul 2 (met 3 hol))
  (to-hex-min hol min)
++  to-hex-min
  |=  [hol=@ min=@ud]
  ^-  @tx
  %-  crip
  ((x-co:co min) hol)
++  to-bytes
  |=  a=@tx
  ^-  @ux
  (scan (trip a) hex)
--
