/*
 *
 *  OLIMP VEC-8U8-16I8-2S32 (Vector Multiply Accumulate)
 *
 *  Copyright (C) 2021  Cristian Balint <cristian dot balint at gmail dot com>
 *
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

//
//  VEC-8U8-16I8-2S32
//
//  Vectors:
//      8 x uint8 ( 64 bit)
//     16 x  int8 (128 bit)
//    ---------------------
//  Lanes:
//      2 x int32 (2x32 bit)

module OLIMP_VEC_8U8_16I8_2S32 (
    input clk_dsp,
    input   [63:0] data,
    input  [127:0] coef,
    output [31:0] acc0,
    output [31:0] acc1
);

    wire [255:0] dot_mul;

    MACC_16_16_32 mul [7:0] (
        .clk    (clk_dsp   ),
        .clk_en (1'b1      ),
        .A      ({2{data}} ),
        .B      (coef      ),
        .X      (dot_mul   )
    );

    assign acc0 = $signed(dot_mul[  0 +: 16])
            + $signed(dot_mul[ 16 +: 16])
            + $signed(dot_mul[ 32 +: 16])
            + $signed(dot_mul[ 48 +: 16])
            + $signed(dot_mul[ 64 +: 16])
            + $signed(dot_mul[ 80 +: 16])
            + $signed(dot_mul[ 96 +: 16])
            + $signed(dot_mul[112 +: 16]);
    assign acc1 = $signed(dot_mul[128 +: 16])
            + $signed(dot_mul[144 +: 16])
            + $signed(dot_mul[160 +: 16])
            + $signed(dot_mul[176 +: 16])
            + $signed(dot_mul[192 +: 16])
            + $signed(dot_mul[208 +: 16])
            + $signed(dot_mul[224 +: 16])
            + $signed(dot_mul[240 +: 16]);
endmodule

module MACC_16_16_32 (
    input         clk,
    input         clk_en,
    input  [15:0] A, B,
    output [31:0] X
);
`ifndef SYNTHESIS
    reg [15:0] r1A, r2A, r3A;
    reg [15:0] r1B, r2B, r3B;

    // MAC needs 3 x clock cycle
    always @(posedge clk) begin
        if (clk_en) begin
            r1A <= $signed(A[ 7:0]) * $signed(B[ 7:0]);
            r1B <= $signed(A[15:8]) * $signed(B[15:8]);
            r2A <= r1A;
            r2B <= r1B;
            r3A <= r2A;
            r3B <= r2B;
        end
    end

    assign X = {r3B, r3A};
`else
    SB_MAC16 #(
        .NEG_TRIGGER              (1'b  0),

        .A_REG                    (1'b  1),
        .B_REG                    (1'b  1),
        .C_REG                    (1'b  0),
        .D_REG                    (1'b  0),

        .TOP_8x8_MULT_REG         (1'b  1),
        .BOT_8x8_MULT_REG         (1'b  1),

        .PIPELINE_16x16_MULT_REG1 (1'b  1),
        .PIPELINE_16x16_MULT_REG2 (1'b  0),

        .TOPOUTPUT_SELECT         (2'b 10),
        .TOPADDSUB_LOWERINPUT     (2'b 00),
        .TOPADDSUB_UPPERINPUT     (1'b  0),
        .TOPADDSUB_CARRYSELECT    (2'b 00),

        .BOTOUTPUT_SELECT         (2'b 10),
        .BOTADDSUB_LOWERINPUT     (2'b 00),
        .BOTADDSUB_UPPERINPUT     (1'b  0),
        .BOTADDSUB_CARRYSELECT    (2'b 00),

        .MODE_8x8                 (1'b  1),
        .A_SIGNED                 (1'b  1),
        .B_SIGNED                 (1'b  1)
    ) mac16 (
        // inputs
        .CLK        (clk   ),
        .CE         (clk_en),

        .A          (A     ),
        .B          (B     ),
        .C          (16'b 0),
        .D          (16'b 0),

        .AHOLD      (1'b 0 ),
        .BHOLD      (1'b 0 ),
        .CHOLD      (1'b 0 ),
        .DHOLD      (1'b 0 ),

        .IRSTTOP    (1'b 0 ),
        .IRSTBOT    (1'b 0 ),
        .ORSTTOP    (1'b 0 ),
        .ORSTBOT    (1'b 0 ),
        .OLOADTOP   (1'b 0 ),
        .OLOADBOT   (1'b 0 ),

        .ADDSUBTOP  (1'b 0 ),
        .ADDSUBBOT  (1'b 0 ),
        .OHOLDTOP   (1'b 0 ),
        .OHOLDBOT   (1'b 0 ),
        .CI         (1'b 0 ),
        .ACCUMCI    (1'b 0 ),
        .SIGNEXTIN  (1'b 0 ),

        // outputs
        .O          (X     ),
        .CO         (      ),
        .ACCUMCO    (      ),
        .SIGNEXTOUT (      )
    );
`endif
endmodule
