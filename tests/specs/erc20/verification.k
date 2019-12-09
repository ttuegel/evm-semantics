requires "evm.k"
requires "edsl2.k"

module VERIFICATION
    imports EVM
    imports EDSL2

    rule .Bytes +Bytes BS => BS [simplification]
    rule BS +Bytes .Bytes => BS [simplification]

endmodule
