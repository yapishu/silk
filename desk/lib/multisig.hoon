::  lib/multisig.hoon: 2-of-3 Cosmos native multisig for %silk escrow
::
::  amino binary encoding, multisig address derivation,
::  amino JSON sign docs, partial signing, and protobuf tx assembly.
::
/-  *protobuf3
/+  *protobuf3, *proto
|%
::
::  bech32 encoding (minimal inline, no external bitcoin deps)
::
++  bech32
  |%
  ++  charset  "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
  ++  polymod
    |=  values=(list @)
    ^-  @
    =/  gen=(list @ux)
      ~[0x3b6a.57b2 0x2650.8e6d 0x1ea1.19fa 0x3d42.33dd 0x2a14.62b3]
    =/  chk=@  1
    |-
    ?~  values  chk
    =/  top  (rsh [0 25] chk)
    =.  chk  (mix i.values (lsh [0 5] (dis chk 0x1ff.ffff)))
    =/  j=@ud  0
    |-
    ?:  =(j 5)  ^$(values t.values)
    =?  chk  =(1 (dis 1 (rsh [0 j] top)))
      (mix chk (snag j gen))
    $(j +(j))
  ++  expand-hrp
    |=  hrp=tape
    ^-  (list @)
    =/  front  (turn hrp |=(p=@tD (rsh [0 5] p)))
    =/  back   (turn hrp |=(p=@tD (dis 31 p)))
    (zing ~[front ~[0] back])
  ++  make-checksum
    |=  [hrp=tape data=(list @)]
    ^-  (list @)
    =/  pmod=@
      %+  mix  1
      %-  polymod
      (zing ~[(expand-hrp hrp) data (reap 6 0)])
    %+  turn  (gulf 0 5)
    |=(i=@ (dis 31 (rsh [0 (mul 5 (sub 5 i))] pmod)))
  ++  value-to-charset
    |=  value=@
    ^-  (unit @tD)
    ?:  (gth value 31)  ~
    `(snag value charset)
  ++  encode-raw
    |=  [hrp=tape data=(list @)]
    ^-  @t
    =/  combined=(list @)  (weld data (make-checksum hrp data))
    %-  crip
    (zing ~[hrp "1" (tape (murn combined value-to-charset))])
  --
::
::  convert big-endian atom to byte list (MSB first)
::
++  atom-to-bytes
  |=  [a=@ n=@ud]
  ^-  (list @)
  %+  turn  (gulf 0 (dec n))
  |=  i=@ud
  (cut 3 [(sub (dec n) i) 1] a)
::
::  convert byte list (big-endian) to atom
::
++  bytes-to-atom
  |=  bs=(list @)
  ^-  @
  (rep 3 (flop bs))
::
::  convert big-endian atom (n bytes) to list of 5-bit groups
::
++  bytes-to-5bit
  |=  [data=@ n-bytes=@ud]
  ^-  (list @)
  =/  n-bits=@ud  (mul n-bytes 8)
  =/  n-groups=@ud  (div n-bits 5)
  %+  turn  (gulf 0 (dec n-groups))
  |=  i=@ud
  (dis 0x1f (rsh [0 (mul 5 (sub (dec n-groups) i))] data))
::
::  SHA256 with big-endian I/O (matches zhax from zenith lib)
::
++  zhax
  |=  ruz=@
  ^-  @
  (swp 3 (shax (swp 3 ruz)))
::
::  @ud to cord (e.g. 123 -> '123')
::
++  ud-to-cord
  |=  n=@ud
  ^-  @t
  (crip (a-co:co n))
::
::  sort compressed secp256k1 pubkeys lexicographically
::
++  sort-pubkeys
  |=  pks=(list @ux)
  ^-  (list @ux)
  %+  sort  pks
  |=  [a=@ux b=@ux]
  (lth a b)
::
::  generate secp256k1 keypair from seed
::
++  gen-escrow-key
  |=  seed=@
  ^-  [pub=@ux priv=@ux]
  =/  priv=@ux  `@ux`(shax (jam seed))
  =/  pub=@ux
    =+  secp256k1:secp:crypto
    (compress-point (priv-to-pub priv))
  [pub priv]
::
::  amino binary encoding for 2-of-3 multisig pubkey
::
::  amino prefix for "tendermint/PubKeyMultisigThreshold": 0x22C430A5
::  amino prefix for "tendermint/PubKeySecp256k1": 0xEB5AE98721
::
::  structure:
::    prefix(4) + length(varint) +
::      threshold_field(08 02) +
::      pubkey_field(12 26 EB5AE98721 <33-byte-pk>) * 3
::
++  amino-marshal-multisig-pubkey
  |=  pubkeys=(list @ux)
  ^-  @  ::  big-endian atom of amino binary
  ?>  =(3 (lent pubkeys))
  =/  sorted=(list @ux)  (sort-pubkeys pubkeys)
  ::  amino prefix for tendermint/PubKeyMultisigThreshold
  =/  prefix=(list @)  ~[0x22 0xc1 0xf7 0xe2]
  ::  inner content: threshold field + pubkey fields
  =/  inner=(list @)  ~[0x8 0x2]  ::  field 1 (varint), threshold=2
  ::  each pubkey: field tag + length + amino secp256k1 prefix + key
  =.  inner
    =/  pks  sorted
    |-
    ?~  pks  inner
    =/  pk-bytes=(list @)  (atom-to-bytes i.pks 33)
    =/  entry=(list @)
      ;:  weld
        ~[0x12 0x26]                      ::  field 2 tag + length(38)
        ~[0xeb 0x5a 0xe9 0x87 0x21]       ::  secp256k1 amino prefix
        pk-bytes
      ==
    $(pks t.pks, inner (weld inner entry))
  ::  assemble: prefix + inner (no length varint — MarshalBinaryBare)
  =/  all-bytes=(list @)  (weld prefix inner)
  (bytes-to-atom all-bytes)
::
::  derive 2-of-3 multisig address
::
::  SHA256(amino_binary)[:20] -> bech32("zenith", ...)
::  note: multisig uses SHA256[:20], NOT RIPEMD160(SHA256)
::
++  derive-multisig-address
  |=  pubkeys=(list @ux)
  ^-  @t  ::  bech32 address
  =/  amino-bytes=@  (amino-marshal-multisig-pubkey pubkeys)
  =/  hash=@  (zhax amino-bytes)
  ::  take first 20 bytes (big-endian: shift right by 12 bytes)
  =/  hash-20=@  (rsh [3 12] hash)
  ::  convert 20 bytes to 32 5-bit groups
  =/  groups=(list @)  (bytes-to-5bit hash-20 20)
  (encode-raw:bech32 "zenith" groups)
::
::  amino JSON SignDoc for MsgSend (canonical, keys sorted)
::
::  this is the exact byte sequence each signer SHA256-hashes
::  and ECDSA-signs for SIGN_MODE_LEGACY_AMINO_JSON.
::
++  amino-json-sign-doc-send
  |=  $:  from=@t       ::  multisig address
          to=@t         ::  recipient address
          amount=@ud    ::  amount in smallest denom
          denom=@t      ::  e.g. '$sZ'
          fee=@ud
          gas=@ud
          chain-id=@t
          account-number=@ud
          sequence=@ud
      ==
  ^-  @t
  =/  amt-s=@t  (ud-to-cord amount)
  =/  fee-s=@t  (ud-to-cord fee)
  =/  gas-s=@t  (ud-to-cord gas)
  =/  acc-s=@t  (ud-to-cord account-number)
  =/  seq-s=@t  (ud-to-cord sequence)
  %+  rap  3
  :~  '{"account_number":"'  acc-s
      '","chain_id":"'  chain-id
      '","fee":{"amount":[{"amount":"'  fee-s
      '","denom":"'  denom
      '"}],"gas":"'  gas-s
      '"},"memo":"","msgs":[{"type":"cosmos-sdk/MsgSend","value":{"amount":[{"amount":"'
      amt-s
      '","denom":"'  denom
      '"}],"from_address":"'  from
      '","to_address":"'  to
      '"}}],"sequence":"'  seq-s
      '"}'
  ==
::
::  sign a multisig part (amino JSON -> SHA256 -> ECDSA secp256k1)
::
::  returns 64-byte R||S signature
::
++  sign-multisig-part
  |=  [sign-doc=@t priv-key=@ux]
  ^-  @ux
  ::  SHA256 of the JSON cord bytes
  ::  shax reads bytes from LSB (position 0) which is first char of cord
  ::  output: swap to big-endian for ECDSA scalar
  =/  hash  (swp 3 (shax sign-doc))
  =+  (ecdsa-raw-sign:secp256k1:secp:crypto hash priv-key)
  (cat 8 s r)  ::  R||S (64 bytes)
::
::  build CompactBitArray for 3-bit multisig
::
::  signer-indices: which of the 3 signers signed (0-indexed)
::  returns the single elems byte
::
++  mk-bitarray-byte
  |=  signer-indices=(list @ud)
  ^-  @
  =/  acc=@  0
  =/  idxs  signer-indices
  |-
  ?~  idxs  acc
  ?>  (lth i.idxs 3)
  $(idxs t.idxs, acc (con acc (lsh [0 (sub 7 i.idxs)] 1)))
::
::  build protobuf AuthInfo for 2-of-3 multisig tx
::
++  mk-auth-info-multisig
  |=  $:  pubkeys=(list @ux)       ::  all 3 sorted pubkeys
          signer-indices=(list @ud) ::  which 2 signed
          sequence=@ud
          fee-denom=@t
          fee-amount=@ud
          gas-limit=@ud
      ==
  ^-  message-bare
  ::  each secp256k1 pubkey wrapped in Any
  =/  pk-anys=(list message-bare)
    %+  turn  pubkeys
    |=  pk=@ux
    (mk-any '/cosmos.crypto.secp256k1.PubKey' (mk-message-bare [1 bytes+[`33 pk]]~))
  ::  LegacyAminoPubKey: threshold + repeated pubkey Anys
  =/  multisig-pk=message-bare
    %-  mk-message-bare
    :~  [1 uint32+2]
        [2 repeated+embedded+pk-anys]
    ==
  ::  wrap in Any
  =/  multisig-pk-any=message-bare
    (mk-any '/cosmos.crypto.multisig.LegacyAminoPubKey' multisig-pk)
  ::  CompactBitArray: 3 bits total
  =/  elems=@  (mk-bitarray-byte signer-indices)
  =/  bitarray-msg=message-bare
    %-  mk-message-bare
    :~  [1 uint32+3]
        [2 bytes+[`1 elems]]
    ==
  ::  ModeInfo.Multi with per-signer Single modes (amino JSON)
  =/  single-amino=message-bare  (mk-message-bare [1 enum+127]~)
  =/  mode-info-singles=(list message-bare)
    (reap (lent signer-indices) (mk-message-bare [1 embedded+single-amino]~))
  =/  multi-msg=message-bare
    %-  mk-message-bare
    :~  [1 embedded+bitarray-msg]
        [2 repeated+embedded+mode-info-singles]
    ==
  ::  ModeInfo uses field 2 for multi (oneof sum)
  =/  mode-info-msg=message-bare
    (mk-message-bare [2 embedded+multi-msg]~)
  ::  SignerInfo
  =/  signer-info-msg=message-bare
    %-  mk-message-bare
    :~  [1 embedded+multisig-pk-any]
        [2 embedded+mode-info-msg]
        [3 uint64+sequence]
    ==
  ::  Fee
  =/  coin-msg  (mk-coin fee-denom fee-amount)
  =/  fee-msg=message-bare
    %-  mk-message-bare
    :~  [1 repeated+embedded+~[coin-msg]]
        [2 uint64+gas-limit]
    ==
  ::  AuthInfo
  %-  mk-message-bare
  :~  [1 repeated+embedded+~[signer-info-msg]]
      [2 embedded+fee-msg]
  ==
::
::  assemble 2-of-3 multisig tx for broadcast
::
::  returns hex-encoded protobuf TxRaw
::
++  assemble-multisig-tx
  |=  $:  from=@t               ::  multisig address
          to=@t                 ::  recipient address
          amount=@ud            ::  transfer amount
          denom=@t              ::  denomination (e.g. '$sZ')
          fee=@ud               ::  fee amount
          gas=@ud               ::  gas limit
          chain-id=@t
          account-number=@ud
          sequence=@ud
          pubkeys=(list @ux)    ::  all 3 sorted pubkeys
          signer-indices=(list @ud)  ::  which 2 signed (0-indexed)
          signatures=(list @ux) ::  the 2 R||S signatures (64 bytes each)
      ==
  ^-  @t  ::  hex-encoded tx bytes
  ::  build TxBody with MsgSend
  =/  body-bytes=@ux
    (to-bytes (encode-message (mk-tx-body-send from to denom amount)))
  ::  build AuthInfo with multisig structure
  =/  auth-info-bytes=@ux
    %-  to-bytes
    %-  encode-message
    (mk-auth-info-multisig (sort-pubkeys pubkeys) signer-indices sequence denom fee gas)
  ::  build MultiSignature protobuf: repeated bytes signatures
  =/  multi-sig=message-bare
    %-  mk-message-bare
    :~  [1 repeated+bytes+(turn signatures |=(s=@ux [`64 s]))]
    ==
  =/  multi-sig-bytes=@ux  (to-bytes (encode-message multi-sig))
  ::  build TxRaw (can't use mk-tx-raw because sig length != 64)
  =/  msb=@ud  (met 3 multi-sig-bytes)
  =/  tx-raw=message-bare
    %-  mk-message-bare
    :~  [1 bytes+`body-bytes]
        [2 bytes+`auth-info-bytes]
        [3 repeated+bytes+~[[`msb multi-sig-bytes]]]
    ==
  (encode-message tx-raw)
--
