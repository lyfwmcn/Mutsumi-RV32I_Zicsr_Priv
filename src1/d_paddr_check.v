`timescale 1ns / 1ns

module d_paddr_check (
    input              clk,

    input      [1:0]   privilege,
    input      [31:0]  pmpaddr0,
    input      [31:0]  pmpaddr1,
    input      [31:0]  pmpaddr2,
    input      [31:0]  pmpaddr3,
    input      [31:0]  pmpcfg0,

    input              op,
    input              tlb_pwc_fill,
    input      [31:0]  paddr,
    output reg         access_fault,
    output reg         cached
);

function automatic [1:0] pma;
    input [31:0] paddr;
    begin
        pma = paddr[31:24] != 8'h0 ? 2'h0 :  // 未映射区域
              paddr[23] ? 2'h2 :             // I/D 均不可缓存区域
              paddr[22:10] == 13'h0 ? 2'h3 : // I 可缓存，D 不可缓存区域
              2'h1;                          // I/D 均可缓存区域
    end
endfunction

function automatic pmp_hit;
    input [31:0] paddr;
    input [7:0]  pmpcfg;
    input [31:0] pre_pmpaddr;
    input [31:0] pmpaddr;
    begin
        case (pmpcfg[4:3])
            2'h1: begin
                pmp_hit = pre_pmpaddr <= paddr &&
                          paddr < pmpaddr;
            end
            2'h2: begin
                pmp_hit = paddr == pmpaddr;
            end
            2'h3: begin
                pmp_hit = ((pmpaddr ^ paddr) & ~(pmpaddr ^ (pmpaddr + 32'h1))) == 32'h0;
            end
            default: begin
                pmp_hit = 1'h0;
            end
        endcase
    end
endfunction

function automatic pmp_fit;
    input        op;
    input [1:0]  privilege;
    input [7:0]  pmpcfg;
    begin
        if (privilege == 2'h3) begin
            pmp_fit = !pmpcfg[7] || (op ? pmpcfg[1] : pmpcfg[0]);
        end
        else begin
            pmp_fit = op ? pmpcfg[1] : pmpcfg[0];
        end
    end
endfunction

wire _op = tlb_pwc_fill ? 1'h0 : op;
wire [1:0] _privilege = tlb_pwc_fill ? 2'h1 : privilege;

wire pmp = pmp_hit(paddr, pmpcfg0[7:0],   32'h0,    pmpaddr0) ? pmp_fit(_op, _privilege, pmpcfg0[7:0]  ) :
           pmp_hit(paddr, pmpcfg0[15:8],  pmpaddr0, pmpaddr1) ? pmp_fit(_op, _privilege, pmpcfg0[15:8] ) :
           pmp_hit(paddr, pmpcfg0[23:16], pmpaddr1, pmpaddr2) ? pmp_fit(_op, _privilege, pmpcfg0[23:16]) :
           pmp_hit(paddr, pmpcfg0[31:24], pmpaddr2, pmpaddr3) ? pmp_fit(_op, _privilege, pmpcfg0[31:24]) :
           _privilege == 2'h3;

always @(posedge clk) begin
    access_fault <= 1'h0;
    cached       <= 1'h1;
    if (!pmp) begin
        access_fault <= 1'h1;
    end
    else begin
        case (pma(paddr))
            2'h0: begin
                // 未映射
                access_fault <= 1'h1;
            end
            2'h1: begin
                // 可缓存
                cached <= 1'h1;
            end
            default: begin
                // 正常访问不可缓存
                // 走表作未映射
                if (tlb_pwc_fill) begin
                    access_fault <= 1'h1;
                end
                else begin
                    cached <= 1'h0;
                end
            end
        endcase
    end
end

endmodule
