`timescale 1ns / 1ns

// 需保证 next_privilege = 2'h0, 2'h1, 2'h3
module privilege_mode (
    input            clk,
    input            rst_n,
    input            ret,
    input            trap,
    input      [1:0] nextprivilege,
    output reg [1:0] privilege
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        privilege <= 2'h3;
    end
    else if (trap || ret) begin
        privilege <= nextprivilege;
    end
end

endmodule
