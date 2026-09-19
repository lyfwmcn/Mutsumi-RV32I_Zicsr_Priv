`timescale 1ns / 1ns

// 需保证 next_privilege = 2'h0, 2'h1, 2'h3
module privilege_mode (
    input            clk,
    input            ret,
    input            trap,
    input      [1:0] nextprivilege,
    output reg [1:0] privilege
);

initial begin
    privilege = 2'h3;
end

always @(posedge clk) begin
    if (trap || ret) begin
        privilege <= nextprivilege;
    end
end

endmodule
