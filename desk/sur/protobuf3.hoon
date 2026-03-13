|%
+|  %defs
+$  message-type
  $:  name=@t
      url=(unit @t)  :: for packing into an Any later I guess
      field-defs=(map @ud field-def)
  ==
+$  field-def
  $:  name=@t
      type=field-type
  ==
+$  field-type
  $@  ?(primitive-atom %string %bytes)
  $%  [%embedded type=message-type]
      $:  %repeated
          $%  [%packed type=primitive]
              [%expanded type=field-type]
      ==  ==
      [%enum =enum]
  ==
+$  primitive-atom
  ?(%int32 %int64 %uint32 %uint64 %sint32 %sint64 %bool %fixed64 %sfixed64 %double %fixed32 %sfixed32 %float)
+$  primitive
  $@  primitive-atom
  [%enum =enum]
+$  enum
  $:  name=@t
      values=(map @ud (set @t))
  ==
+|  %things
+$  message-full
  $:  type=message-type
      fields=(map @ud field-full)
  ==
+$  field-full
  $:  name=@t
      value=field-value-full
  ==
+$  field-value-full
  $%  [%embedded msg=message-full]
      $:  %repeated
          $%  [%packed type=primitive values=(list field-value-full)]
              [%expanded type=field-type values=(list field-value-full)]
      ==  ==
      [?(%uint32 %uint64) value=@ud]
      [?(%int32 %int64 %fixed64 %fixed32 %sint32 %sint64 %sfixed64 %sfixed32) value=@sd]
      [%double value=@rd]
      [%float value=@rs]
      [%enum =enum value=@ud]
      [%bool value=?]
      [%string value=@t]
      [%bytes value=@]
  ==
+$  message-bare  (map @ud field-bare)
+$  field-bare
  $%  [%embedded msg=message-bare]
      [%repeated field-repeated-bare]
      [?(%uint32 %uint64 %fixed32 %fixed64 %enum) value=@ud]
      [?(%int32 %int64 %sfixed32 %sfixed64 %sint32 %sint64) value=@sd]
      [%double value=@rd]
      [%float value=@rs]
      [%bool value=?]
      [%string value=@t]
      [%bytes len=(unit @ud) value=@]
  ==
+$  field-repeated-bare
  $%  [type=%embedded values=(list message-bare)]
      [type=?(%uint32 %uint64 %fixed32 %fixed64 %enum) values=(list @ud)]
      [type=?(%int32 %int64 %sfixed32 %sfixed64 %sint32 %sint64) values=(list @sd)]
      [type=%double values=(list @rd)]
      [type=%float values=(list @rs)]
      [type=%bool values=(list ?)]
      [type=%string values=(list @t)]
      [type=%bytes values=(list [len=(unit @ud) value=@])]
  ==
+$  unpackable  ?(%string %bytes %embedded)
+|  %wire-type-enum
+$  wire-type  ?(%0 %1 %2 %5)
++  varint  `wire-type`%0
++  i64     `wire-type`%1
++  len     `wire-type`%2
++  i32     `wire-type`%5
--
