`timescale 1ns / 1ns

// 5.6 ns
// 需保证 wb_csr_in 符合格式
module trap_csr_bypass (
    input             clk,
    input             rst_n,
    input             flush,
    input             stall,
    input             cur_MIE,
    input             cur_MPIE,
    input             cur_SIE,
    input             cur_SPIE,
    input             cur_SPP,
    input             m2_csr_wr,
    input             wb_csr_wr,
    input      [1:0]  cur_MPP,
    input      [1:0]  privilege,
    input      [3:0]  m1_fstcause,
    input      [11:0] m2_csr_rd,
    input      [11:0] wb_csr_rd,
    input      [31:0] cur_medeleg,
    input      [31:0] cur_mepc,
    input      [31:0] cur_mideleg,
    input      [31:0] cur_mie,
    input      [31:0] cur_mip,
    input      [31:0] cur_mtvec,
    input      [31:0] cur_sepc,
    input      [31:0] cur_stvec,
    input      [31:0] m2_csr_in,
    input      [31:0] wb_csr_in,
    output reg        interrupt_cause_valid,
    output reg        medeleg_exception_cause,
    output reg        mideleg_interrupt_cause,
    output reg        MIE,
    output reg        MPIE,
    output reg        SIE,
    output reg        SPIE,
    output reg        SPP,
    output reg [1:0]  MPP,
    output reg [3:0]  interrupt_cause,
    output reg [31:0] medeleg,
    output reg [31:0] mepc,
    output reg [31:0] mideleg,
    output reg [31:0] mie,
    output reg [31:0] mip,
    output reg [31:0] mtvec,
    output reg [31:0] sepc,
    output reg [31:0] stvec
);

wire [31:0] _mie =  m2_csr_wr ? (m2_csr_rd == 12'h304 ? m2_csr_in :
                                m2_csr_rd == 12'h104 ? (wb_csr_wr && wb_csr_rd == 12'h304 ? {wb_csr_in[31:10], m2_csr_in[9], wb_csr_in[8:6], m2_csr_in[5], wb_csr_in[4:2], m2_csr_in[1], wb_csr_in[0]} :
                                                    {cur_mie[31:10], m2_csr_in[9], cur_mie[8:6], m2_csr_in[5], cur_mie[4:2], m2_csr_in[1], cur_mie[0]}) :
                                cur_mie) :
                    wb_csr_wr ? (wb_csr_rd == 12'h304 ? wb_csr_in :
                                wb_csr_rd == 12'h104 ? {cur_mie[31:10], wb_csr_in[9], cur_mie[8:6], wb_csr_in[5], cur_mie[4:2], wb_csr_in[1], cur_mie[0]} :
                                cur_mie) :
                    cur_mie;

wire [31:0] _mip =  m2_csr_wr ? (m2_csr_rd == 12'h344 ? {cur_mip[31:4], m2_csr_in[3], cur_mip[2], m2_csr_in[1], cur_mip[0]} :
                                m2_csr_rd == 12'h144 ? (wb_csr_wr && wb_csr_rd == 12'h344 ? {cur_mip[31:4], wb_csr_in[3], cur_mip[2], m2_csr_in[1], cur_mip[0]} :
                                                    {cur_mip[31:2], m2_csr_in[1], cur_mip[0]}) :
                                cur_mip) :
                    wb_csr_wr ? (wb_csr_rd == 12'h344 ? {cur_mip[31:4], wb_csr_in[3], cur_mip[2], wb_csr_in[1], cur_mip[0]} :
                                wb_csr_rd == 12'h144 ? {cur_mip[31:2], wb_csr_in[1], cur_mip[0]} :
                                cur_mip) :
                    cur_mip;

wire [31:0] _mideleg =  m2_csr_wr && m2_csr_rd == 12'h303 ? m2_csr_in :
                        wb_csr_wr && wb_csr_rd == 12'h303 ? wb_csr_in :
                        cur_mideleg;


wire _MIE = m2_csr_wr && m2_csr_rd == 12'h300 ? m2_csr_in[3] :
            wb_csr_wr && wb_csr_rd == 12'h300 ? wb_csr_in[3] :
            cur_MIE;

wire _SIE = m2_csr_wr && (m2_csr_rd == 12'h300 || m2_csr_rd == 12'h100) ? m2_csr_in[1] :
            wb_csr_wr && (wb_csr_rd == 12'h300 || wb_csr_rd == 12'h100) ? wb_csr_in[1] :
            cur_SIE;

wire [3:0] _interrupt_cause;
assign _interrupt_cause =   _mip[11] && _mie[11] && (_mideleg[11] && privilege <= 2'h1 ? _SIE : _MIE) ? 4'hb :
                            _mip[3]  && _mie[3]  && (_mideleg[3]  && privilege <= 2'h1 ? _SIE : _MIE) ? 4'h3 :
                            _mip[7]  && _mie[7]  && (_mideleg[7]  && privilege <= 2'h1 ? _SIE : _MIE) ? 4'h7 :
                            _mip[9]  && _mie[9]  && (_mideleg[9]  && privilege <= 2'h1 ? _SIE : _MIE) ? 4'h9 :
                            _mip[1]  && _mie[1]  && (_mideleg[1]  && privilege <= 2'h1 ? _SIE : _MIE) ? 4'h1 :
                            _mip[5]  && _mie[5]  && (_mideleg[5]  && privilege <= 2'h1 ? _SIE : _MIE) ? 4'h5 :
                            4'h0;



always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        interrupt_cause_valid <= 1'h0;
        medeleg_exception_cause <= 1'h0;
        mideleg_interrupt_cause <= 1'h0;
        MIE <= 1'h0;
        MPIE <= 1'h0;
        SIE <= 1'h0;
        SPIE <= 1'h0;
        SPP <= 1'h0;
        MPP <= 2'h0;
        interrupt_cause <= 4'h0;
        medeleg <= 32'h0;
        mepc <= 32'h0;
        mideleg <= 32'h0;
        mie <= 32'h0;
        mip <= 32'h0;
        mtvec <= 32'h0;
        sepc <= 32'h0;
        stvec <= 32'h0;
    end
    else if (flush) begin
        interrupt_cause_valid <= 1'h0;
        medeleg_exception_cause <= 1'h0;
        mideleg_interrupt_cause <= 1'h0;
        MIE <= 1'h0;
        MPIE <= 1'h0;
        SIE <= 1'h0;
        SPIE <= 1'h0;
        SPP <= 1'h0;
        MPP <= 2'h0;
        interrupt_cause <= 4'h0;
        medeleg <= 32'h0;
        mepc <= 32'h0;
        mideleg <= 32'h0;
        mie <= 32'h0;
        mip <= 32'h0;
        mtvec <= 32'h0;
        sepc <= 32'h0;
        stvec <= 32'h0;
    end
    else if (!stall) begin
        interrupt_cause_valid <= _interrupt_cause != 4'h0;
        medeleg_exception_cause <= medeleg[15:0][m1_fstcause];
        mideleg_interrupt_cause <= _mideleg[15:0][_interrupt_cause];
        MIE <= _MIE;
        MPIE <= m2_csr_wr && m2_csr_rd == 12'h300 ? m2_csr_in[7] :
                wb_csr_wr && wb_csr_rd == 12'h300 ? wb_csr_in[7] :
                cur_MPIE;
        SIE <= _SIE;
        SPIE <= m2_csr_wr && (m2_csr_rd == 12'h300 || m2_csr_rd == 12'h100) ? m2_csr_in[5] :
                wb_csr_wr && (wb_csr_rd == 12'h300 || wb_csr_rd == 12'h100) ? wb_csr_in[5] :
                cur_SPIE;
        SPP <= m2_csr_wr && (m2_csr_rd == 12'h300 || m2_csr_rd == 12'h100) ? m2_csr_in[8] :
               wb_csr_wr && (wb_csr_rd == 12'h300 || wb_csr_rd == 12'h100) ? wb_csr_in[8] :
               cur_SPP;
        MPP <= m2_csr_wr && m2_csr_rd == 12'h300 ? m2_csr_in[12:11] :
               wb_csr_wr && wb_csr_rd == 12'h300 ? wb_csr_in[12:11] :
               cur_MPP;
        interrupt_cause <= _interrupt_cause;
        medeleg <= m2_csr_wr && m2_csr_rd == 12'h302 ? m2_csr_in :
                   wb_csr_wr && wb_csr_rd == 12'h302 ? wb_csr_in :
                   cur_medeleg;
        mepc <= m2_csr_wr && m2_csr_rd == 12'h341 ? m2_csr_in :
                wb_csr_wr && wb_csr_rd == 12'h341 ? wb_csr_in :
                cur_mepc;
        mideleg <= _mideleg;
        mie <= _mie;
        mip <= _mip;
        mtvec <= m2_csr_wr && m2_csr_rd == 12'h305 ? m2_csr_in :
                 wb_csr_wr && wb_csr_rd == 12'h305 ? wb_csr_in :
                 cur_mtvec;
        sepc <= m2_csr_wr && m2_csr_rd == 12'h141 ? m2_csr_in :
                wb_csr_wr && wb_csr_rd == 12'h141 ? wb_csr_in :
                cur_sepc;
        stvec <= m2_csr_wr && m2_csr_rd == 12'h105 ? m2_csr_in :
                 wb_csr_wr && wb_csr_rd == 12'h105 ? wb_csr_in :
                 cur_stvec;
    end
end

endmodule
