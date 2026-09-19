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
    #1000
    $display("100:       %h", system_bus.mem[100]);
    // $display("101:       %h", system_bus.mem[101]);
    // $display("102:       %h", system_bus.mem[102]);
    // $display("103:       %h", system_bus.mem[103]);
    // $display("104:     %h", SystemBus.mem[104]);
    // $display("105:     %h", SystemBus.mem[105]);
    // $display("106:     %h", SystemBus.mem[106]);
    // $display("107:     %h", SystemBus.mem[107]);
    $display("x1/ra:     %h", cpu.reg_file.regs[1]);
    $display("x2/sp:     %h", cpu.reg_file.regs[2]);
    $display("x3/gp:     %h", cpu.reg_file.regs[3]);
    $display("x4/tp:     %h", cpu.reg_file.regs[4]);
    $display("x5/t0:     %h", cpu.reg_file.regs[5]);
    $display("x6/t1:     %h", cpu.reg_file.regs[6]);
    // $display("x7/t2:     %h", cpu.reg_file.regs[7]);
    // $display("x8/s0/fp:  %h", cpu.reg_file.regs[8]);
    // $display("x9/s1:     %h", cpu.reg_file.regs[9]);
    // $display("x10/a0:    %h", cpu.reg_file.regs[10]);
    // $display("x11/a1:    %h", cpu.reg_file.regs[11]);
    // $display("x12/a2:    %h", cpu.reg_file.regs[12]);
    // $display("x13/a3:    %h", cpu.reg_file.regs[13]);
    // $display("x14/a4:    %h", cpu.reg_file.regs[14]);
    // $display("x15/a5:    %h", cpu.reg_file.regs[15]);
    // $display("x16/a6:    %h", cpu.reg_file.regs[16]);
    // $display("x17/a7:    %h", cpu.reg_file.regs[17]);
    // $display("x18/s2:    %h", cpu.reg_file.regs[18]);
    // $display("x19/s3:    %h", cpu.reg_file.regs[19]);
    // $display("x20/s4:    %h", cpu.reg_file.regs[20]);
    // $display("x21/s5:    %h", cpu.reg_file.regs[21]);
    // $display("x22/s6:    %h", cpu.reg_file.regs[22]);
    // $display("x23/s7:    %h", cpu.reg_file.regs[23]);
    // $display("x24/s8:    %h", cpu.reg_file.regs[24]);
    // $display("x25/s9:    %h", cpu.reg_file.regs[25]);
    // $display("x26/s10:   %h", cpu.reg_file.regs[26]);
    // $display("x27/s11:   %h", cpu.reg_file.regs[27]);
    // $display("x28/t3:    %h", cpu.reg_file.regs[28]);
    // $display("x29/t4:    %h", cpu.reg_file.regs[29]);
    // $display("x30/t5:    %h", cpu.reg_file.regs[30]);
    // $display("x31/t6:    %h", cpu.reg_file.regs[31]);
    $finish;
end

initial begin
    $dumpfile("build/wave.vcd");
    $dumpvars(0, tb);
end

endmodule
