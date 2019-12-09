eDSL High-Level Notations
=========================

The eDSL high-level notations make the EVM specifications more succinct and closer to their high-level specifications.
The succinctness increases the readability, and the closeness helps "eye-ball validation" of the specification refinement.
The high-level notations are defined by translation to the corresponding EVM terms, and thus can be freely used with other EVM terms.
The notations are inspired by the production compilers of the smart contract languages like Solidity and Vyper, and their definition is derived by formalizing the corresponding translation made by the compilers.

```k
requires "evm.k"

module EDSL2         [symbolic]
    imports EVM
```

### ABI Call Data

When a function is called in the EVM, its arguments are encoded in a single byte-array and put in the so-called 'call data' section.
The encoding is defined in the [Ethereum contract application binary interface (ABI) specification](https://solidity.readthedocs.io/en/develop/abi-spec.html).
The eDSL provides `#abiCallData`, a notation to specify the ABI call data in a way similar to a high-level function call notation, defined below.
It specifies the function name and the (symbolic) arguments along with their types.
For example, the following notation represents a data that encodes a call to the `transfer` function with two arguments: `TO`, the receiver account address of type `address` (an 160-bit unsigned integer), and `VALUE`, the value to transfer of type `unit256` (a 256-bit unsigned integer).

```
  #abiCallData("transfer", #address(TO), #uint256(VALUE))
```

which denotes (indeed, is translated to) the following byte array:

```
  F1 : F2 : F3 : F4 : T1 : ... : T32 : V1 : ... : V32
```

where `F1 : F2 : F3 : F4` is the (two's complement) byte-array representation of `2835717307`, the first four bytes of the hash value of the `transfer` function signature, `keccak256("transfer(address,unit256)")`, and `T1 : ... : T32` and `V1 : ... : V32` are the byte-array representations of `TO` and `VALUE` respectively.

```k
    syntax TypedArg ::= #uint160 ( Int )
                      | #address ( Int )
                      | #uint256 ( Int )
                      | #uint48  ( Int )
                      | #uint16  ( Int )
                      | #uint8   ( Int )
                      | #int256  ( Int )
                      | #int128  ( Int )
                      | #bytes32 ( Int )
                      | #bool    ( Int )
                      | #bytes   ( ByteArray )
                      | #string  ( String )
                      | #array   ( TypedArg , Int , TypedArgs )
 // -----------------------------------------------------------

    syntax TypedArgs ::= List{TypedArg, ","} [klabel(typedArgs)]
 // ------------------------------------------------------------

    syntax ByteArray ::= #abiCallData ( String , TypedArgs ) [function]
 // -------------------------------------------------------------------
    rule #abiCallData( FNAME , ARGS )
      => #parseByteStack(substrString(Keccak256(#generateSignature(FNAME, ARGS)), 0, 8))
      ++ #encodeArgs(ARGS)

    syntax String ::= #generateSignature     ( String, TypedArgs ) [function]
                    | #generateSignatureArgs ( TypedArgs )         [function]
 // -------------------------------------------------------------------------
    rule #generateSignature( FNAME , ARGS ) => FNAME +String "(" +String #generateSignatureArgs(ARGS) +String ")"

    rule #generateSignatureArgs(.TypedArgs)                            => ""
    rule #generateSignatureArgs(TARGA:TypedArg, .TypedArgs)            => #typeName(TARGA)
    rule #generateSignatureArgs(TARGA:TypedArg, TARGB:TypedArg, TARGS) => #typeName(TARGA) +String "," +String #generateSignatureArgs(TARGB, TARGS)

    syntax String ::= #typeName ( TypedArg ) [function]
 // ---------------------------------------------------
    rule #typeName(   #uint160( _ )) => "uint160"
    rule #typeName(   #address( _ )) => "address"
    rule #typeName(   #uint256( _ )) => "uint256"
    rule #typeName(    #uint48( _ )) => "uint48"
    rule #typeName(    #uint16( _ )) => "uint16"
    rule #typeName(     #uint8( _ )) => "uint8"
    rule #typeName(    #int256( _ )) => "int256"
    rule #typeName(    #int128( _ )) => "int128"
    rule #typeName(   #bytes32( _ )) => "bytes32"
    rule #typeName(      #bool( _ )) => "bool"
    rule #typeName(     #bytes( _ )) => "bytes"
    rule #typeName(    #string( _ )) => "string"
    rule #typeName( #array(T, _, _)) => #typeName(T) +String "[]"

    syntax ByteArray ::= #encodeArgs    ( TypedArgs )                               [function]
    syntax ByteArray ::= #encodeArgsAux ( TypedArgs , Int , ByteArray , ByteArray ) [function]
 // ------------------------------------------------------------------------------------------
    rule #encodeArgs(ARGS) => #encodeArgsAux(ARGS, #lenOfHeads(ARGS), .ByteArray, .ByteArray)

    rule #encodeArgsAux(.TypedArgs, _:Int, HEADS, TAILS) => HEADS ++ TAILS

    rule #encodeArgsAux((ARG, ARGS), OFFSET, HEADS, TAILS)
        => #encodeArgsAux(ARGS, OFFSET, HEADS ++ #enc(ARG), TAILS)
      requires #isStaticType(ARG)

    rule #encodeArgsAux((ARG, ARGS), OFFSET, HEADS, TAILS)
        => #encodeArgsAux(ARGS, OFFSET +Int #sizeOfDynamicType(ARG), HEADS ++ #enc(#uint256(OFFSET)), TAILS ++ #enc(ARG))
      requires notBool(#isStaticType(ARG))

    syntax Int ::= #lenOfHeads ( TypedArgs ) [function]
 // ---------------------------------------------------
    rule #lenOfHeads(.TypedArgs) => 0
    rule #lenOfHeads(ARG, ARGS)  => #lenOfHead(ARG) +Int #lenOfHeads(ARGS)

    syntax Int ::= #lenOfHead ( TypedArg ) [function]
 // -------------------------------------------------
    rule #lenOfHead(  #uint160( _ )) => 32
    rule #lenOfHead(  #address( _ )) => 32
    rule #lenOfHead(  #uint256( _ )) => 32
    rule #lenOfHead(   #uint48( _ )) => 32
    rule #lenOfHead(   #uint16( _ )) => 32
    rule #lenOfHead(    #uint8( _ )) => 32
    rule #lenOfHead(   #int256( _ )) => 32
    rule #lenOfHead(   #int128( _ )) => 32
    rule #lenOfHead(  #bytes32( _ )) => 32
    rule #lenOfHead(     #bool( _ )) => 32
    rule #lenOfHead(    #bytes( _ )) => 32
    rule #lenOfHead(   #string( _ )) => 32
    rule #lenOfHead(#array(_, _, _)) => 32

    syntax Bool ::= #isStaticType ( TypedArg ) [function]
 // -----------------------------------------------------
    rule #isStaticType(  #uint160( _ )) => true
    rule #isStaticType(  #address( _ )) => true
    rule #isStaticType(  #uint256( _ )) => true
    rule #isStaticType(   #uint48( _ )) => true
    rule #isStaticType(   #uint16( _ )) => true
    rule #isStaticType(    #uint8( _ )) => true
    rule #isStaticType(   #int256( _ )) => true
    rule #isStaticType(   #int128( _ )) => true
    rule #isStaticType(  #bytes32( _ )) => true
    rule #isStaticType(     #bool( _ )) => true
    rule #isStaticType(    #bytes( _ )) => false
    rule #isStaticType(   #string( _ )) => false
    rule #isStaticType(#array(_, _, _)) => false

    syntax Int ::= #sizeOfDynamicType ( TypedArg ) [function]
 // ---------------------------------------------------------
    rule #sizeOfDynamicType(#bytes(BS)) => 32 +Int #ceil32(#sizeByteArray(BS))

    rule #sizeOfDynamicType(#array(T, N, _)) => 32 *Int (1 +Int N)
      requires #isStaticType(T)

    rule #sizeOfDynamicType(#array(T, N, ELEMS)) => 32 *Int (1 +Int N +Int #sizeOfDynamicTypeAux(ELEMS))
      requires notBool #isStaticType(T)

    syntax Int ::= #sizeOfDynamicTypeAux ( TypedArgs ) [function]
 // -------------------------------------------------------------
    rule #sizeOfDynamicTypeAux(TARG, TARGS) => #sizeOfDynamicType(TARG) +Int #sizeOfDynamicTypeAux(TARGS)
      requires notBool #isStaticType(TARG)

    rule #sizeOfDynamicTypeAux(.TypedArgs) => 0

    syntax ByteArray ::= #enc ( TypedArg ) [function]
 // -------------------------------------------------
    // static Type
    rule #enc(#uint160( DATA )) => #buf(32, #getValue(#uint160( DATA )))
    rule #enc(#address( DATA )) => #buf(32, #getValue(#address( DATA )))
    rule #enc(#uint256( DATA )) => #buf(32, #getValue(#uint256( DATA )))
    rule #enc( #uint48( DATA )) => #buf(32, #getValue( #uint48( DATA )))
    rule #enc( #uint16( DATA )) => #buf(32, #getValue( #uint16( DATA )))
    rule #enc(  #uint8( DATA )) => #buf(32, #getValue(  #uint8( DATA )))
    rule #enc( #int256( DATA )) => #buf(32, #getValue( #int256( DATA )))
    rule #enc( #int128( DATA )) => #buf(32, #getValue( #int128( DATA )))
    rule #enc(#bytes32( DATA )) => #buf(32, #getValue(#bytes32( DATA )))
    rule #enc(   #bool( DATA )) => #buf(32, #getValue(   #bool( DATA )))

    // dynamic Type
    rule #enc(        #bytes(BS)) => #encBytes(#sizeByteArray(BS), BS)
    rule #enc(#array(_, N, DATA)) => #enc(#uint256(N)) ++ #encodeArgs(DATA)
    rule #enc(      #string(STR)) => #enc(#bytes(#parseByteStackRaw(STR)))

    syntax ByteArray ::= #encBytes ( Int , ByteArray ) [function]
 // -------------------------------------------------------------
    rule #encBytes(N, BS) => #enc(#uint256(N)) ++ BS ++ #buf(#ceil32(N) -Int N, 0)

    //Byte array buffer. Lemmas defined in evm-data-symbolic.k
    // SIZE, DATA // left zero padding
    syntax ByteArray ::= #buf ( Int , Int ) [function, functional, smtlib(buf)]
 // ---------------------------------------------------------------------------

    syntax Int ::= #getValue ( TypedArg ) [function]
 // ------------------------------------------------
    rule #getValue(#uint160( DATA )) => DATA
      requires #rangeUInt(160, DATA)

    rule #getValue(#address( DATA )) => DATA
      requires #rangeAddress(DATA)

    rule #getValue(#uint256( DATA )) => DATA
      requires #rangeUInt(256, DATA)

    rule #getValue(  #uint48( DATA )) => DATA
      requires #rangeUInt(48, DATA)

    rule #getValue(  #uint16( DATA )) => DATA
      requires #rangeUInt(16, DATA)

    rule #getValue(  #uint8( DATA )) => DATA
      requires #rangeUInt(8, DATA)

    rule #getValue( #int256( DATA )) => #unsigned(DATA)
      requires #rangeSInt(256, DATA)

    rule #getValue( #int128( DATA )) => #unsigned(DATA)
      requires #rangeSInt(128, DATA)

    rule #getValue(#bytes32( DATA )) => DATA
      requires #rangeUInt(256, DATA)

    rule #getValue(   #bool( DATA )) => DATA
      requires #range(0 <= DATA <= 1)

    syntax Int ::= #ceil32 ( Int ) [function, smtlib(ceil32), smt-prelude]
 // -----------------------------------------
    rule [#ceil32]: #ceil32(N) => ((N +Int 31) /Int 32) *Int 32
```

```k
endmodule
```
