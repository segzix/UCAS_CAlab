`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/09/30 14:07:26
// Design Name: 
// Module Name: Div
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Div(
    input  wire    div_clk,
    input  wire    reset,
    input  wire    div,
    input  wire    div_signed,
    input  wire [31:0] x,
    input  wire [31:0] y,
    output wire [31:0] s,
    output wire [31:0] r,
    output wire    div_complete 
    );
    wire        sign_s;
    wire        sign_r;
    wire [31:0] abs_x;
    wire [31:0] abs_y;
    wire [32:0] pre_r;
    wire [32:0] recover_r;
    reg  [63:0] x_pad;
    reg  [32:0] y_pad;
    reg  [31:0] s_r;
    reg  [32:0] r_r;
    reg  [ 5:0] cnt;
    assign sign_s = (x[31]^y[31]) & div_signed;
    assign sign_r = x[31] & div_signed;
    assign abs_x  = (div_signed & x[31]) ? (~x+1'b1): x;
    assign abs_y  = (div_signed & y[31]) ? (~y+1'b1): y;
    assign div_complete = cnt == 6'd33;
    always @(posedge div_clk) begin
        if(reset) begin
            cnt <= 6'b0;
        end else if(div) begin
            if(div_complete)
                cnt <= 6'b0;
            else
                cnt <= cnt + 1'b1;
        end
    end
    always @(posedge div_clk) begin
        if(reset) begin
            x_pad <= 64'd0;
            y_pad <= 33'd0;
        end else if(div) begin
            if(~|cnt) begin
                x_pad <= {32'd0,abs_x};
                y_pad <= {1'd0,abs_y};
            end
        end
    end
    assign pre_r = r_r - y_pad;
    assign recover_r = pre_r[32] ? r_r : pre_r;
    always @(posedge div_clk) begin
        if(reset) 
            s_r <= 32'b0;
        else if(div & ~div_complete & | cnt) begin
            s_r[32-cnt] <= ~pre_r[32];
        end
    end
    always @(posedge div_clk) begin
        if(reset)
            r_r <= 33'b0;
        if(div & ~div_complete) begin
            if(~|cnt)
                r_r <= {32'b0, abs_x[31]};
            else
                r_r <=  (cnt == 32) ? recover_r : {recover_r, x_pad[31 - cnt]};
        end
    end
    assign s = div_signed & sign_s ? (~s_r+1'b1) : s_r;
    assign r = div_signed & sign_r ? (~r_r+1'b1) : r_r;
endmodule
