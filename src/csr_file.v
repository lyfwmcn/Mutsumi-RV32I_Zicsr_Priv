`timescale 1ns / 1ns

// 写 5.2 ns，读 6.2 ns
// 需保证 csr_in 符合格式
// 需保证 next_MPP, next_mcause, next_mepc, next_mtval 符合格式
module csr_file (
    input             clk,

    input             external_interrupt_clear,
    input             external_interrupt_set,
    input             timer_interrupt_clear,
    input             timer_interrupt_set,

    input             csr_wr,
    input             next_MIE,
    input             next_MPIE,
    input             next_SIE,
    input             next_SPIE,
    input             next_SPP,
    input             ret,
    input             ret_type,
    input             trap,
    input             trap_type,
    input             wb_is_instr,
    input      [1:0]  next_MPP,
    input      [11:0] csr_rd,
    input      [11:0] csr_rs,
    input      [31:0] csr_in,
    input      [31:0] next_mcause,
    input      [31:0] next_mepc,
    input      [31:0] next_mtval,
    input      [31:0] next_stval,
    input      [31:0] next_sepc,
    input      [31:0] next_scause,
    output            cur_MIE,
    output            cur_MPIE,
    output            cur_SIE,
    output            cur_SPIE,
    output            cur_SPP,
    output     [1:0]  cur_MPP,
    output reg [31:0] csr_out,
    output     [31:0] cur_medeleg,
    output     [31:0] cur_mepc,
    output     [31:0] cur_mideleg,
    output     [31:0] cur_mie,
    output     [31:0] cur_mip,
    output     [31:0] cur_mtvec,
    output     [31:0] cur_sepc,
    output     [31:0] cur_stvec
);

reg es0, es1, es2;
reg ec0, ec1, ec2;
reg ts0, ts1, ts2;
reg tc0, tc1, tc2;

initial begin
    es0 = 1'h0;
    es1 = 1'h0;
    es2 = 1'h0;
    ec0 = 1'h0;
    ec1 = 1'h0;
    ec2 = 1'h0;
    ts0 = 1'h0;
    ts1 = 1'h0;
    ts2 = 1'h0;
    tc0 = 1'h0;
    tc1 = 1'h0;
    tc2 = 1'h0;
end

always @(posedge clk) begin
    es0 <= external_interrupt_set;
    es1 <= es0;
    es2 <= es1;
    ec0 <= external_interrupt_clear;
    ec1 <= ec0;
    ec2 <= ec1;
    ts0 <= timer_interrupt_set;
    ts1 <= ts0;
    ts2 <= ts1;
    tc0 <= timer_interrupt_clear;
    tc1 <= tc0;
    tc2 <= tc1;
end

reg [31:0] stvec;
reg [31:0] sscratch;
reg [31:0] sepc;
reg [31:0] scause;
reg [31:0] stval;
reg [31:0] satp;
reg [31:0] mstatus;
reg [31:0] misa;
reg [31:0] medeleg;
reg [31:0] mideleg;
reg [31:0] mie;
reg [31:0] mtvec;
reg [31:0] mscratch;
reg [31:0] mepc;
reg [31:0] mcause;
reg [31:0] mtval;
reg [31:0] mip;
reg [31:0] mcycle;
reg [31:0] minstret;
reg [31:0] mcycleh;
reg [31:0] minstreth;
reg [31:0] mhartid;

initial begin
    stvec = 32'h0;
    sscratch = 32'h0;
    sepc = 32'h0;
    scause = 32'h0;
    stval = 32'h0;
    satp = 32'h0;
    mstatus = 32'h0;
    misa = 32'h40000100;
    medeleg = 32'h0;
    mideleg = 32'h0;
    mie = 32'h0;
    mtvec = 32'h0;
    mscratch = 32'h0;
    mepc = 32'h0;
    mcause = 32'h0;
    mtval = 32'h0;
    mip = 32'h0;
    mcycle = 32'h0;
    minstret = 32'h0;
    mcycleh = 32'h0;
    minstreth = 32'h0;
    mhartid = 32'h0;
end

always @(*) begin
    case (csr_rs)
        12'h100: csr_out = {mstatus[31:23], 3'h0, mstatus[19:18], 1'h0, mstatus[16:13], 2'h0, mstatus[10:8], 1'h0, mstatus[6:4], 1'h0, mstatus[2:0]};
        12'h104: csr_out = {mie[31:12], 1'h0, mie[10:8], 1'h0, mie[6:4], 1'h0, mie[2:0]};
        12'h105: csr_out = stvec;
        12'h140: csr_out = sscratch;
        12'h141: csr_out = sepc;
        12'h142: csr_out = scause;
        12'h143: csr_out = stval;
        12'h144: csr_out = {mip[31:12], 1'h0, mip[10:8], 1'h0, mip[6:4], 1'h0, mip[2:0]};
        12'h180: csr_out = satp;
        12'h300: csr_out = mstatus;
        12'h301: csr_out = misa;
        12'h302: csr_out = medeleg;
        12'h303: csr_out = mideleg;
        12'h304: csr_out = mie;
        12'h305: csr_out = mtvec;
        12'h340: csr_out = mscratch;
        12'h341: csr_out = mepc;
        12'h342: csr_out = mcause;
        12'h343: csr_out = mtval;
        12'h344: csr_out = mip;
        12'hB00: csr_out = mcycle;
        12'hB02: csr_out = minstret;
        12'hB80: csr_out = mcycleh;
        12'hB82: csr_out = minstreth;
        12'hF14: csr_out = mhartid;
        default: csr_out = 32'h0;
    endcase
end

assign cur_MIE = mstatus[3];
assign cur_MPIE = mstatus[7];
assign cur_MPP = mstatus[12:11];
assign cur_SIE = mstatus[1];
assign cur_SPIE = mstatus[5];
assign cur_SPP = mstatus[8];
assign cur_medeleg = medeleg;
assign cur_mepc = mepc;
assign cur_mideleg = mideleg;
assign cur_mie = mie;
assign cur_mip = mip;
assign cur_mtvec = mtvec;
assign cur_sepc = sepc;
assign cur_stvec = stvec;

always @(posedge clk) begin
    {mcycleh, mcycle} <= {mcycleh, mcycle} + 64'h1;
    if (wb_is_instr == 1'h1) begin
        {minstreth, minstret} <= {minstreth, minstret} + 64'h1;
    end
    if (ec1 ^ ec2) begin
        mip[11] <= 1'h0;
    end
    if (es1 ^ es2) begin
        mip[11] <= 1'h1;
    end
    if (tc1 ^ tc2) begin
        mip[7] <= 1'h0;
    end
    if (ts1 ^ ts2) begin
        mip[7] <= 1'h1;
    end
    if (csr_wr == 1'h1) begin
        case (csr_rd)
            12'h100: {mstatus[19:18], mstatus[8], mstatus[5], mstatus[1]} <= {csr_in[19:18], csr_in[8], csr_in[5], csr_in[1]};
            12'h104: {mie[9], mie[5], mie[1]} <= {csr_in[9], csr_in[5], csr_in[1]};
            12'h105: stvec <= csr_in;
            12'h140: sscratch <= csr_in;
            12'h141: sepc <= csr_in;
            12'h142: scause <= csr_in;
            12'h143: stval <= csr_in;
            12'h144: mip[1] <= csr_in[1];
            12'h180: satp <= csr_in;
            12'h300: mstatus <= csr_in;
            12'h302: medeleg <= csr_in;
            12'h303: mideleg <= csr_in;
            12'h304: mie <= csr_in;
            12'h305: mtvec <= csr_in;
            12'h340: mscratch <= csr_in;
            12'h341: mepc <= csr_in;
            12'h342: mcause <= csr_in;
            12'h343: mtval <= csr_in;
            12'h344: {mip[3], mip[1]} <= {csr_in[3], csr_in[1]};
            default: ;
        endcase
    end
    if (ret == 1'h1) begin
        if (ret_type == 1'h0) begin
            mstatus[3] <= next_MIE;
            mstatus[7] <= next_MPIE;
            mstatus[12:11] <= next_MPP;
        end
        else begin
            mstatus[1] <= next_SIE;
            mstatus[5] <= next_SPIE;
            mstatus[8] <= next_SPP;
        end
    end
    if (trap == 1'h1) begin
        if (trap_type == 1'h0) begin
            mstatus[3] <= next_MIE;
            mstatus[7] <= next_MPIE;
            mstatus[12:11] <= next_MPP;
            mcause <= next_mcause;
            mepc <= next_mepc;
            mtval <= next_mtval;
        end
        else begin
            mstatus[1] <= next_SIE;
            mstatus[5] <= next_SPIE;
            mstatus[8] <= next_SPP;
            scause <= next_scause;
            sepc <= next_sepc;
            stval <= next_stval;
        end
    end
end

endmodule
