/-  *protobuf3
/+  *protobuf3
|%
+|  %types
++  sign-doc
  %^  mk-message-type  'SignDoc'  ~
  :~  [1 'body_bytes' %bytes]
      [2 'auth_info_bytes' %bytes]
      [3 'chain_id' %string]
      [4 'account_number' %uint64]
  ==
++  tx-body
  %^  mk-message-type  'TxBody'  ~
  :~  [1 'messages' repeated+expanded+embedded+any:google-protobuf]
      [2 'memo' %string]
      [3 'timeout_height' %uint64]
      [4 'unordered' %bool]
      [5 'timeout_timestamp' embedded+timestamp:google-protobuf]
      [1.023 'extension_options' repeated+expanded+embedded+any:google-protobuf]
      [2.047 'non_critical_extension_options' repeated+expanded+embedded+any:google-protobuf]
  ==
++  auth-info
  %^  mk-message-type  'AuthInfo'  ~
  :~  [1 'signer_infos' repeated+expanded+embedded+signer-info]
      [2 'fee' embedded+fee]
  ==
++  signer-info
  %^  mk-message-type  'SignerInfo'  ~
  :~  [1 'public_key' embedded+any:google-protobuf]
      [2 'mode_info' embedded+mode-info]
      [3 'sequence' %uint64]
  ==
++  mode-info
  %^  mk-message-type  'ModeInfo'  ~
  :~  [1 'single' embedded+single]
      [2 'multi' embedded+multi]
  ==
++  single
  %^  mk-message-type  'Single'  ~
  :~  [1 'mode' enum+sign-mode]
  ==
++  multi
  %^  mk-message-type  'Multi'  ~
  :~  [1 'bitarray' embedded+compact-bit-array]
      [2 'mode_infos' repeated+expanded+embedded+mode-info]
  ==
++  compact-bit-array
  %^  mk-message-type  'CompactBitArray'  ~
  :~  [1 'extra_bits_stored' %uint32]
      [2 'elems' %bytes]
  ==
++  fee
  %^  mk-message-type  'Fee'  ~
  :~  [1 'amount' repeated+expanded+embedded+coin]
      [2 'gas_limit' %uint64]
      [3 'payer' %string]
      [4 'granter' %string]
  ==
++  sign-mode
  %+  mk-enum  'SignMode'
  :~  [0 'SIGN_MODE_UNSPECIFIED']
      [1 'SIGN_MODE_DIRECT']
      [2 'SIGN_MODE_TEXTUAL']
      [3 'SIGN_MODE_DIRECT_AUX']
      [127 'SIGN_MODE_LEGACY_AMINO_JSON']
      [191 'SIGN_MODE_EIP_191']
  ==
++  google-protobuf
  |%
  ++  any
    %^  mk-message-type  'Any'  ~
    :~  [1 'type_url' %string]
        [2 'value' %bytes]
    ==
  ++  timestamp  *mk-message-type  :: todo: make it real?
  --
++  msg-send
  ^-  message-type
  %^  mk-message-type  'MsgSend'
    `'/cosmos.bank.v1beta1.MsgSend'
  :~  [1 'from_address' %string]
      [2 'to_address' %string]
      [3 'amount' repeated+expanded+embedded+coin]
  ==
++  coin
  %^  mk-message-type  'Coin'  ~
  :~  [1 'denom' %string]
      [2 'amount' %string]
  ==
::
+|  %builders
++  mk-tx-raw
  |=  [body-bytes=@ux auth-info-bytes=@ux signatures=(list @ux)]
  =/  sigs=(list [(unit @ud) @])
    %+  turn  signatures
    |=  sig=@ux
    [`64 sig]
  %-  mk-message-bare
  :~  [1 bytes+`body-bytes]
      [2 bytes+`auth-info-bytes]
      [3 repeated+bytes+sigs]
  ==
++  mk-sign-doc-basic
  |=  [from=@t to=@t denom=@t amount=@ud fee=@ud gas-limit=@ud sequence=@ud chain-id=@t account-number=@ud pub-key=@]
  ^-  [body-bytes=@ux auth-info-bytes=@ux sign-doc-msg=message-bare]
  =/  body-bytes  (to-bytes (encode-message (mk-tx-body-send from to denom amount)))
  =/  auth-info-bytes
    (to-bytes (encode-message (mk-auth-info-basic pub-key sequence denom fee gas-limit)))
  :+  body-bytes  auth-info-bytes
  %-  mk-message-bare
  :~  [1 bytes+`body-bytes]
      [2 bytes+`auth-info-bytes]
      [3 string+chain-id]
      [4 uint64+account-number]
  ==
++  mk-tx-body-send
  |=  send=[from=@t to=@t denom=@t amount=@ud]
  %-  mk-message-bare
  [1 repeated+embedded+~[(mk-any (need url:msg-send) (mk-msg-send send))]]~
::
++  mk-auth-info-basic
  |=  [pub-key=@ sequence=@ud fee-denom=@t fee-amount=@ud gas-limit=@ud]
  %-  mk-message-bare
  =/  public-key-msg
    %+  mk-any
       '/cosmos.crypto.secp256k1.PubKey'
    (mk-message-bare [1 bytes+`pub-key]~)
  =/  mode-info-msg
    %-  mk-message-bare
    [1 embedded+(mk-message-bare [1 enum+1]~)]~
  =/  signer-info-msg
    %-  mk-message-bare
    :~  [1 embedded+public-key-msg]
        [2 embedded+mode-info-msg]
        [3 uint64+sequence]
    ==
  =/  fee-msg
    =/  coin-msg  (mk-coin fee-denom fee-amount)
    %-  mk-message-bare
    :~  [1 repeated+embedded+~[coin-msg]]
        [2 uint64+gas-limit]
    ==
  :~  [1 repeated+embedded+~[signer-info-msg]]
      [2 embedded+fee-msg]
  ==
++  mk-any
  |=  [url=@t value=message-bare]
  %-  mk-message-bare
  :~  [1 string+url]
      [2 bytes+`(to-bytes (encode-message value))]
  ==
++  mk-msg-send
  |=  [from=@t to=@t denom=@t amount=@ud]
  =/  coin-msg  (mk-coin denom amount)
  %-  mk-message-bare
  :~  [1 string+from]
      [2 string+to]
      [3 repeated+embedded+~[coin-msg]]
  ==
++  mk-coin
  |=  [denom=@t amount=@ud]
  %-  mk-message-bare
  :~  [1 string+denom]
      [2 string+(crip (a-co:co amount))]
  ==

--
