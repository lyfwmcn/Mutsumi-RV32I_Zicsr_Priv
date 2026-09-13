`timescale 1ns / 1ns

// 需保证 CSRin 符合格式
// 需保证 NextMPP, Nextmcause, Nextmepc, Nextmtval 符合格式
module CSRFile (
    input CLK,
    input RST,

    input External_Interrupt_Clear,
    input External_Interrupt_Set,
    input Timer_Interrupt_Clear,
    input Timer_Interrupt_Set,

    input CSRWr,
    input NextMIE,
    input NextMPIE,
    input NextSIE,
    input NextSPIE,
    input NextSPP,
    input Ret,
    input RetType,
    input Trap,
    input TrapType,
    input WBIsInstr,
    input [1:0] NextMPP,
    input [11:0] CSRRd,
    input [11:0] CSRRs,
    input [31:0] CSRin,
    input [31:0] Nextmcause,
    input [31:0] Nextmepc,
    input [31:0] Nextmtval,
    input [31:0] Nextstval,
    input [31:0] Nextsepc,
    input [31:0] Nextscause,
    output CurMIE,
    output CurMPIE,
    output CurSIE,
    output CurSPIE,
    output CurSPP,
    output [1:0] CurMPP,
    output [31:0] CSRout,
    output [31:0] Curmedeleg,
    output [31:0] Curmepc,
    output [31:0] Curmideleg,
    output [31:0] Curmie,
    output [31:0] Curmip,
    output [31:0] Curmtvec,
    output [31:0] Cursepc,
    output [31:0] Curstvec
);

reg es0, es1, es2;
reg ec0, ec1, ec2;
reg ts0, ts1, ts2;
reg tc0, tc1, tc2;

always @(posedge CLK or posedge RST) begin
    if (RST) begin
        es0 <= 1'h0;
        es1 <= 1'h0;
        es2 <= 1'h0;
        ec0 <= 1'h0;
        ec1 <= 1'h0;
        ec2 <= 1'h0;
        ts0 <= 1'h0;
        ts1 <= 1'h0;
        ts2 <= 1'h0;
        tc0 <= 1'h0;
        tc1 <= 1'h0;
        tc2 <= 1'h0;
    end
    else begin
        es0 <= External_Interrupt_Set;
        es1 <= es0;
        es2 <= es1;
        ec0 <= External_Interrupt_Clear;
        ec1 <= ec0;
        ec2 <= ec1;
        ts0 <= Timer_Interrupt_Set;
        ts1 <= ts0;
        ts2 <= ts1;
        tc0 <= Timer_Interrupt_Clear;
        tc1 <= tc0;
        tc2 <= tc1;
    end
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

assign CSRout = CSRRs == 12'h100 ? {mstatus[31:23], 3'h0, mstatus[19:18], 1'h0, mstatus[16:13], 2'h0, mstatus[10:8], 1'h0, mstatus[6:4], 1'h0, mstatus[2:0]} :
                CSRRs == 12'h104 ? {mie[31:12], 1'h0, mie[10:8], 1'h0, mie[6:4], 1'h0, mie[2:0]} :
                CSRRs == 12'h105 ? stvec :
                CSRRs == 12'h140 ? sscratch :
                CSRRs == 12'h141 ? sepc :
                CSRRs == 12'h142 ? scause :
                CSRRs == 12'h143 ? stval :
                CSRRs == 12'h144 ? {mip[31:12], 1'h0, mip[10:8], 1'h0, mip[6:4], 1'h0, mip[2:0]} :
                CSRRs == 12'h180 ? satp :
                CSRRs == 12'h300 ? mstatus :
                CSRRs == 12'h301 ? misa :
                CSRRs == 12'h302 ? medeleg :
                CSRRs == 12'h303 ? mideleg :
                CSRRs == 12'h304 ? mie :
                CSRRs == 12'h305 ? mtvec :
                CSRRs == 12'h340 ? mscratch :
                CSRRs == 12'h341 ? mepc :
                CSRRs == 12'h342 ? mcause :
                CSRRs == 12'h343 ? mtval :
                CSRRs == 12'h344 ? mip :
                CSRRs == 12'hB00 ? mcycle :
                CSRRs == 12'hB02 ? minstret :
                CSRRs == 12'hB80 ? mcycleh :
                CSRRs == 12'hB82 ? minstreth :
                CSRRs == 12'hF14 ? mhartid :
                32'h0;
assign CurMIE = mstatus[3];
assign CurMPIE = mstatus[7];
assign CurMPP = mstatus[12:11];
assign CurSIE = mstatus[1];
assign CurSPIE = mstatus[5];
assign CurSPP = mstatus[8];
assign Curmedeleg = medeleg;
assign Curmepc = mepc;
assign Curmideleg = mideleg;
assign Curmie = mie;
assign Curmip = mip;
assign Curmtvec = mtvec;
assign Cursepc = sepc;
assign Curstvec = stvec;

initial begin
    misa <= 32'h40000100;
    mhartid <= 32'h0;
end

always @(posedge CLK or posedge RST) begin
    if (RST == 1'h1) begin
        stvec <= 32'h0;
        sscratch <= 32'h0;
        sepc <= 32'h0;
        scause <= 32'h0;
        stval <= 32'h0;
        satp <= 32'h0;
        mstatus <= 32'h0;
        medeleg <= 32'h0;
        mideleg <= 32'h0;
        mie <= 32'h0;
        mtvec <= 32'h0;
        mscratch <= 32'h0;
        mepc <= 32'h0;
        mcause <= 32'h0;
        mtval <= 32'h0;
        mip <= 32'h0;
        mcycle <= 32'h0;
        minstret <= 32'h0;
        mcycleh <= 32'h0;
        minstreth <= 32'h0;
    end
    else begin
        {mcycleh, mcycle} <= {mcycleh, mcycle} + 64'h1;
        if (WBIsInstr == 1'h1) begin
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
        if (CSRWr == 1'h1) begin
            case (CSRRd)
                12'h100: {mstatus[19:18], mstatus[8], mstatus[5], mstatus[1]} <= {CSRin[19:18], CSRin[8], CSRin[5], CSRin[1]};
                12'h104: {mie[9], mie[5], mie[1]} <= {CSRin[9], CSRin[5], CSRin[1]};
                12'h105: stvec <= CSRin;
                12'h140: sscratch <= CSRin;
                12'h141: sepc <= CSRin;
                12'h142: scause <= CSRin;
                12'h143: stval <= CSRin;
                12'h144: mip[1] <= CSRin[1];
                12'h180: satp <= CSRin;
                12'h300: mstatus <= CSRin;
                12'h302: medeleg <= CSRin;
                12'h303: mideleg <= CSRin;
                12'h304: mie <= CSRin;
                12'h305: mtvec <= CSRin;
                12'h340: mscratch <= CSRin;
                12'h341: mepc <= CSRin;
                12'h342: mcause <= CSRin;
                12'h343: mtval <= CSRin;
                12'h344: {mip[3], mip[1]} <= {CSRin[3], CSRin[1]};
                default: ;
            endcase
        end
        if (Ret == 1'h1) begin
            if (RetType == 1'h0) begin
                mstatus[3] <= NextMIE;
                mstatus[7] <= NextMPIE;
                mstatus[12:11] <= NextMPP;
            end
            else begin
                mstatus[1] <= NextSIE;
                mstatus[5] <= NextSPIE;
                mstatus[8] <= NextSPP;
            end
        end
        if (Trap == 1'h1) begin
            if (TrapType == 1'h0) begin
                mstatus[3] <= NextMIE;
                mstatus[7] <= NextMPIE;
                mstatus[12:11] <= NextMPP;
                mcause <= Nextmcause;
                mepc <= Nextmepc;
                mtval <= Nextmtval;
            end
            else begin
                mstatus[1] <= NextSIE;
                mstatus[5] <= NextSPIE;
                mstatus[8] <= NextSPP;
                scause <= Nextscause;
                sepc <= Nextsepc;
                stval <= Nextstval;
            end
        end
    end
end

endmodule
