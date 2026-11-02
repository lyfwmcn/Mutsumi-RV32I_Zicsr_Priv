// 仅仿真用的 ECP5 原语行为模型（综合时 yosys 用自带的 blackbox）
`timescale 1ns/1ps
module ODDRX1F (input SCLK, input RST, input D0, input D1, output reg Q);
    always @(posedge SCLK) Q <= RST ? 1'b0 : D0;
endmodule
module IDDRX1F (input D, input SCLK, input RST, output reg Q0, output reg Q1);
    always @(posedge SCLK) Q0 <= RST ? 1'b0 : D;
    always @(negedge SCLK) Q1 <= RST ? 1'b0 : D;
endmodule
module TRELLIS_IO (inout B, input I, input T, output O);
    parameter DIR = "INPUT";
    assign B = (DIR == "OUTPUT" || DIR == "BIDIR") ? (T ? 1'bz : I) : 1'bz;
    assign O = (DIR == "INPUT" || DIR == "BIDIR") ? B : 1'bx;
endmodule

// PIC 里的 I/O 寄存器（合成时 yosys 映射成 TRELLIS_FF + syn_useioff）
//   BX：复位/置位为 1；DX：复位/清零为 0
module OFS1P3BX (input PD, input D, input SP, input SCLK, output reg Q);
    parameter GSR = "ENABLED";
    initial Q = 1'b1;
    always @(posedge SCLK) if (PD) Q <= 1'b1; else if (SP) Q <= D;
endmodule

module OFS1P3DX (input CD, input D, input SP, input SCLK, output reg Q);
    parameter GSR = "ENABLED";
    initial Q = 1'b0;
    always @(posedge SCLK) if (CD) Q <= 1'b0; else if (SP) Q <= D;
endmodule

module IFS1P3BX (input PD, input D, input SP, input SCLK, output reg Q);
    parameter GSR = "ENABLED";
    initial Q = 1'b1;
    always @(posedge SCLK) if (PD) Q <= 1'b1; else if (SP) Q <= D;
endmodule

module IFS1P3DX (input CD, input D, input SP, input SCLK, output reg Q);
    parameter GSR = "ENABLED";
    initial Q = 1'b0;
    always @(posedge SCLK) if (CD) Q <= 1'b0; else if (SP) Q <= D;
endmodule

module BB (input I, input T, output O, inout B);
    assign B = T ? 1'bz : I;
    assign O = B;
endmodule
