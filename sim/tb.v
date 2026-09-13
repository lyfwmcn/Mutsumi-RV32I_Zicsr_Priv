`timescale 1ns / 1ns

module tb;

reg CLK;
reg RST;

wire Respond_Fault_Data;
wire Respond_Fault_Instr;
wire Respond_Valid_Data;
wire Respond_Valid_Instr;
wire [31:0] Respond_Data_Data;
wire [31:0] Respond_Data_Instr;
wire Request_Valid_Instr;
wire Request_Valid_Data;
wire Request_Write_Data;
wire [3:0] Request_EN_Data;
wire [31:0] Request_Addr_Instr;
wire [31:0] Request_Addr_Data;
wire [31:0] Request_Data_Data;

reg External_Interrupt_Clear;
reg External_Interrupt_Set;
reg Timer_Interrupt_Clear;
reg Timer_Interrupt_Set;

CPU CPU (
    .CLK(CLK),
    .RST(RST),
    .External_Interrupt_Clear(External_Interrupt_Clear),
    .External_Interrupt_Set(External_Interrupt_Set),
    .Timer_Interrupt_Clear(Timer_Interrupt_Clear),
    .Timer_Interrupt_Set(Timer_Interrupt_Set),
    .Respond_Fault_Data(Respond_Fault_Data),
    .Respond_Fault_Instr(Respond_Fault_Instr),
    .Respond_Valid_Data(Respond_Valid_Data),
    .Respond_Valid_Instr(Respond_Valid_Instr),
    .Respond_Data_Data(Respond_Data_Data),
    .Respond_Data_Instr(Respond_Data_Instr),
    .Request_Valid_Data(Request_Valid_Data),
    .Request_Valid_Instr(Request_Valid_Instr),
    .Request_Write_Data(Request_Write_Data),
    .Request_EN_Data(Request_EN_Data),
    .Request_Addr_Data(Request_Addr_Data),
    .Request_Addr_Instr(Request_Addr_Instr),
    .Request_Data_Data(Request_Data_Data)
);

SystemBus SystemBus (
    .CLK(CLK),
    .RST(RST),
    .Request_Valid_Data(Request_Valid_Data),
    .Request_Valid_Instr(Request_Valid_Instr),
    .Request_Write_Data(Request_Write_Data),
    .Request_EN_Data(Request_EN_Data),
    .Request_Addr_Data(Request_Addr_Data),
    .Request_Addr_Instr(Request_Addr_Instr),
    .Request_Data_Data(Request_Data_Data),
    .Respond_Fault_Data(Respond_Fault_Data),
    .Respond_Fault_Instr(Respond_Fault_Instr),
    .Respond_Valid_Data(Respond_Valid_Data),
    .Respond_Valid_Instr(Respond_Valid_Instr),
    .Respond_Data_Data(Respond_Data_Data),
    .Respond_Data_Instr(Respond_Data_Instr)
);

initial begin
    RST = 1;
    #5
    RST = 0;
    #5
    CLK = 0;
    forever #5 CLK = ~CLK;
end

initial begin
    External_Interrupt_Clear <= 1'h0;
    External_Interrupt_Set <= 1'h0;
    Timer_Interrupt_Clear <= 1'h0;
    Timer_Interrupt_Set <= 1'h0;
    #500
    Timer_Interrupt_Set <= 1'h1;
    #10
    Timer_Interrupt_Clear <= 1'h1;
    #20000
    // $display("188:     %h", SystemBus.mem[188]);
    // $display("189:     %h", SystemBus.mem[189]);
    // $display("190:     %h", SystemBus.mem[190]);
    // $display("191:     %h", SystemBus.mem[191]);
    // $display("104:     %h", SystemBus.mem[104]);
    // $display("105:     %h", SystemBus.mem[105]);
    // $display("106:     %h", SystemBus.mem[106]);
    // $display("107:     %h", SystemBus.mem[107]);
    // $display("x1/ra:     %h", CPU.RegFile.regs[1]);
    // $display("x2/sp:     %h", CPU.RegFile.regs[2]);
    // $display("x3/gp:     %h", CPU.RegFile.regs[3]);
    // $display("x4/tp:     %h", CPU.RegFile.regs[4]);
    $display("x5/t0:     %h", CPU.RegFile.regs[5]);
    $display("x6/t1:     %h", CPU.RegFile.regs[6]);
    // $display("x7/t2:     %h", CPU.RegFile.regs[7]);
    // $display("x8/s0/fp:  %h", CPU.RegFile.regs[8]);
    // $display("x9/s1:     %h", CPU.RegFile.regs[9]);
    // $display("x10/a0:    %h", CPU.RegFile.regs[10]);
    // $display("x11/a1:    %h", CPU.RegFile.regs[11]);
    // $display("x12/a2:    %h", CPU.RegFile.regs[12]);
    // $display("x13/a3:    %h", CPU.RegFile.regs[13]);
    // $display("x14/a4:    %h", CPU.RegFile.regs[14]);
    // $display("x15/a5:    %h", CPU.RegFile.regs[15]);
    // $display("x16/a6:    %h", CPU.RegFile.regs[16]);
    // $display("x17/a7:    %h", CPU.RegFile.regs[17]);
    // $display("x18/s2:    %h", CPU.RegFile.regs[18]);
    // $display("x19/s3:    %h", CPU.RegFile.regs[19]);
    // $display("x20/s4:    %h", CPU.RegFile.regs[20]);
    // $display("x21/s5:    %h", CPU.RegFile.regs[21]);
    // $display("x22/s6:    %h", CPU.RegFile.regs[22]);
    // $display("x23/s7:    %h", CPU.RegFile.regs[23]);
    // $display("x24/s8:    %h", CPU.RegFile.regs[24]);
    // $display("x25/s9:    %h", CPU.RegFile.regs[25]);
    // $display("x26/s10:   %h", CPU.RegFile.regs[26]);
    // $display("x27/s11:   %h", CPU.RegFile.regs[27]);
    // $display("x28/t3:    %h", CPU.RegFile.regs[28]);
    // $display("x29/t4:    %h", CPU.RegFile.regs[29]);
    // $display("x30/t5:    %h", CPU.RegFile.regs[30]);
    // $display("x31/t6:    %h", CPU.RegFile.regs[31]);
    $finish;
end

initial begin
    $dumpfile("build/wave.vcd");
    $dumpvars(0, tb);
end

endmodule
