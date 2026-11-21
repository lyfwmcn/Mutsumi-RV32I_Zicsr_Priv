`timescale 1ns / 1ns

module csr_hazard (
    input        id_is_csr,

    input        ex_is_instr,
    input        me_is_instr,
    input        wb_is_instr,

    output       csr_wait
);

assign csr_wait = id_is_csr &&
                  (ex_is_instr ||
                   me_is_instr ||
                   wb_is_instr);

endmodule
