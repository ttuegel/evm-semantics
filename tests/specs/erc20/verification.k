requires "evm.k"
requires "edsl2.k"

module VERIFICATION
    imports EVM
    imports EDSL2

    rule .Bytes +Bytes BS => BS [simplification]
    rule BS +Bytes .Bytes => BS [simplification]

    rule lengthBytes(B1 +Bytes B2) => lengthBytes(B1) +Int lengthBytes(B2)  [simplification]

    rule lengthBytes(#buf(N, _)) => N [simplification]

    rule substrBytes(padRightBytes(WS, PADLEN, 0), START, END) => substrBytes(WS, START, END)
      requires START <Int END
       andBool END <=Int lengthBytes(WS)
    [simplification]

endmodule
