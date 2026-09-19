`timescale 1ns / 1ns

module tb;

reg clk;

wire        request_valid_data;
wire        request_valid_instr;
wire        request_write_data;
wire [3:0]  request_en_data;
wire [31:0] request_addr_data;
wire [31:0] request_addr_instr;
wire [31:0] request_data_data;

wire        respond_fault_data;
wire        respond_fault_instr;
wire        respond_valid_data;
wire        respond_valid_instr;
wire [31:0] respond_data_data;
wire [31:0] respond_data_instr;

reg external_interrupt_clear;
reg external_interrupt_set;
reg timer_interrupt_clear;
reg timer_interrupt_set;

cpu cpu (
    .clk                     (clk),
    .external_interrupt_clear(external_interrupt_clear),
    .external_interrupt_set  (external_interrupt_set),
    .timer_interrupt_clear   (timer_interrupt_clear),
    .timer_interrupt_set     (timer_interrupt_set),

    .respond_fault_data      (respond_fault_data),
    .respond_fault_instr     (respond_fault_instr),
    .respond_valid_data      (respond_valid_data),
    .respond_valid_instr     (respond_valid_instr),
    .respond_data_data       (respond_data_data),
    .respond_data_instr      (respond_data_instr),

    .request_valid_data      (request_valid_data),
    .request_valid_instr     (request_valid_instr),
    .request_write_data      (request_write_data),
    .request_en_data         (request_en_data),
    .request_addr_data       (request_addr_data),
    .request_addr_instr      (request_addr_instr),
    .request_data_data       (request_data_data)
);

system_bus system_bus (
    .clk                (clk),
    .request_valid_data (request_valid_data),
    .request_valid_instr(request_valid_instr),
    .request_write_data (request_write_data),
    .request_en_data    (request_en_data),
    .request_addr_data  (request_addr_data),
    .request_addr_instr (request_addr_instr),
    .request_data_data  (request_data_data),

    .respond_fault_data (respond_fault_data),
    .respond_fault_instr(respond_fault_instr),
    .respond_valid_data (respond_valid_data),
    .respond_valid_instr(respond_valid_instr),
    .respond_data_data  (respond_data_data),
    .respond_data_instr (respond_data_instr)
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin
    external_interrupt_clear <= 1'h0;
    external_interrupt_set <= 1'h0;
    timer_interrupt_clear <= 1'h0;
    timer_interrupt_set <= 1'h0;
    #500
    timer_interrupt_set <= 1'h1;
    #10
    timer_interrupt_clear <= 1'h1;
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
    $display("x5/t0:     %h", cpu.reg_file.regs[5]);
    $display("x6/t1:     %h", cpu.reg_file.regs[6]);
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
