`timescale 1ns / 1ns

// 6.8 ns
// 需保证 privilege = 2'h0, 2'h1, 2'h3
// 需保证 MPP = 2'h0, 2'h1, 2'h3
module trap_unit (
    input         interrupt_cause_valid,
    input         m2_fstcause_valid,
    input         m2_load_access_fault,
    input         m2_load_page_fault,
    input         m2_store_access_fault,
    input         m2_store_page_fault,
    input         medeleg_exception_cause,
    input         mideleg_interrupt_cause,
    input         MIE,
    input         MPIE,
    input         ret,
    input         ret_type,
    input         SIE,
    input         SPIE,
    input         SPP,
    input  [1:0]  MPP,
    input  [1:0]  privilege,
    input  [3:0]  interrupt_cause,
    input  [3:0]  m2_fstcause,
    input  [31:0] m2_alu_out,
    input  [31:0] m2_instr,
    input  [31:0] m2_pc,
    input  [31:0] m2_pcplusimm,
    input  [31:0] medeleg,
    input  [31:0] mideleg,
    input  [31:0] mie,
    input  [31:0] mip,
    input  [31:0] wb_nextpc,
    output        next_MIE,
    output        next_MPIE,
    output        next_SIE,
    output        next_SPIE,
    output        next_SPP,
    output        trap,
    output        trap_type,
    output [1:0]  next_MPP,
    output [1:0]  nextprivilege,
    output [31:0] next_mcause,
    output [31:0] next_mepc,
    output [31:0] next_mtval,
    output [31:0] next_scause,
    output [31:0] next_sepc,
    output [31:0] next_stval
);

wire [3:0] _exceptioncause;
assign _exceptioncause = m2_fstcause_valid ? m2_fstcause :
                         m2_load_page_fault ? 4'hd :
                         m2_load_access_fault ? 4'h5 :
                         m2_store_page_fault ? 4'hf :
                         m2_store_access_fault ? 4'h7 :
                         4'ha;

wire [3:0] _interruptcause;
assign _interruptcause = interrupt_cause_valid ? interrupt_cause : 4'h0;

assign trap = _exceptioncause != 4'ha || _interruptcause != 4'h0;
wire medeleg_exception_cause_true;
assign medeleg_exception_cause_true = m2_fstcause_valid ? medeleg_exception_cause :
                                        m2_load_page_fault ? medeleg[13] :
                                        m2_load_access_fault ? medeleg[5] :
                                        m2_store_page_fault ? medeleg[15] :
                                        m2_store_access_fault ? medeleg[7] :
                                        medeleg[10];
assign trap_type = _exceptioncause == 4'ha ? (mideleg_interrupt_cause && privilege[1] == 1'h0) : (medeleg_exception_cause_true && privilege[1] == 1'h0);
// 需保证 nextprivilege = 2'h0, 2'h1, 2'h3
assign nextprivilege = trap ? (_exceptioncause == 4'ha ? (mideleg_interrupt_cause && privilege <= 2'h1 ? 2'h1 : 2'h3) : (medeleg_exception_cause_true && privilege <= 2'h1 ? 2'h1 : 2'h3)) :
                       (ret_type ? {1'h0, SPP} : MPP);

assign next_MIE = trap ? 1'h0 : MPIE;
assign next_MPIE = trap ? MIE : 1'h1;
assign next_SIE = trap ? 1'h0 : SPIE;
assign next_SPIE = trap ? SIE : 1'h1;
// 需保证 next_MPP = 2'h0, 2'h1, 2'h3
assign next_MPP = trap ? privilege : 2'h0;
assign next_SPP = trap ? privilege[0] : 1'h0;

// 需保证 next_mcause 符合格式
assign next_mcause = _exceptioncause == 4'ha ? {1'h1, 27'h0, _interruptcause} : {28'h0, _exceptioncause};
// 需保证 next_mepc 符合格式
assign next_mepc = _exceptioncause == 4'ha ? wb_nextpc : m2_pc;
// 需保证 next_mtval 符合格式
assign next_mtval = _exceptioncause == 4'ha ? 32'h0 :
                    _exceptioncause == 4'h3 || _exceptioncause == 4'h8 || _exceptioncause == 4'h9 || _exceptioncause == 4'hb ? 32'h0 :
                    _exceptioncause == 4'h0 ? m2_pcplusimm :
                    _exceptioncause == 4'h1 || _exceptioncause == 4'hc ? m2_pc :
                    _exceptioncause == 4'h2 ? m2_instr :
                    m2_alu_out;
assign next_scause = _exceptioncause == 4'ha ? {1'h1, 27'h0, _interruptcause} : {28'h0, _exceptioncause};
assign next_sepc = _exceptioncause == 4'ha ? wb_nextpc : m2_pc;
assign next_stval = _exceptioncause == 4'ha ? 32'h0 :
                    _exceptioncause == 4'h3 || _exceptioncause == 4'h8 || _exceptioncause == 4'h9 || _exceptioncause == 4'hb ? 32'h0 :
                    _exceptioncause == 4'h0 ? m2_pcplusimm :
                    _exceptioncause == 4'h1 || _exceptioncause == 4'hc ? m2_pc :
                    _exceptioncause == 4'h2 ? m2_instr :
                    m2_alu_out;

endmodule
