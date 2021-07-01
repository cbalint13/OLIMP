/*
 *
 *  Copyright (C) 2017  Clifford Wolf <clifford@clifford.at>
 *                2021  Cristian Balint <cristian dot balint at gmail dot com>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

`ifndef PICORV32_REGS
`ifdef PICORV32_V
`error "picosoc.v must be read before picorv32.v!"
`endif

`define PICORV32_REGS picosoc_regs
`endif

// macro for verilog design order.
`define PICOSOC_V

module picosoc (
    input clk_cpu,
    input clk_spi,
    input resetn,

    output ser_tx,
    input  ser_rx,

    output flash_csb,
    output flash_clk,

    output flash_io0_oe,
    output flash_io1_oe,
    output flash_io2_oe,
    output flash_io3_oe,

    output flash_io0_do,
    output flash_io1_do,
    output flash_io2_do,
    output flash_io3_do,

    input  flash_io0_di,
    input  flash_io1_di,
    input  flash_io2_di,
    input  flash_io3_di
);
    parameter [0:0] ENABLE_PCPI = 1;
    parameter [0:0] BARREL_SHIFTER = 1;
    parameter [0:0] ENABLE_MULDIV = 1;
    parameter [0:0] ENABLE_COUNTERS = 1;
    parameter [0:0] ENABLE_COMPRESSED = 0;

    parameter integer MEM_WORDS = 256;
    parameter [31:0] STACKADDR = (4*MEM_WORDS);       // end of memory
    parameter [31:0] PROGADDR_RESET = 32'h 0010_0000; // 1 MB into flash

    wire mem_valid;
    wire mem_instr;
    wire mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [ 3:0] mem_wstrb;
    wire [31:0] mem_rdata;

    wire pcpi_valid;
    reg pcpi_ready;
    wire [31:0] pcpi_insn;
    wire [31:0] pcpi_rs1;
    wire [31:0] pcpi_rs2;
    reg [31:0] pcpi_rd;

    wire spimem_ready;
    wire [31:0] spimem_rdata;

    reg ram_ready;
    wire [31:0] ram_rdata;

    wire rxtx_ready;
    wire [31:0] rxtx_rdata;

    reg coef_ready;
    wire [31:0] coef_rdata;

    assign mem_ready = spimem_ready || ram_ready || rxtx_ready || coef_ready;

    assign mem_rdata = spimem_ready ? spimem_rdata
                     : ram_ready ? ram_rdata
                     : rxtx_ready ? rxtx_rdata
                     : coef_ready ? coef_rdata
                     : 32'h 0000_0000;

    picorv32 #(
        .STACKADDR(STACKADDR),
        .PROGADDR_RESET(PROGADDR_RESET),
        .BARREL_SHIFTER(BARREL_SHIFTER),
        .COMPRESSED_ISA(ENABLE_COMPRESSED),
        .ENABLE_COUNTERS(ENABLE_COUNTERS),
        .ENABLE_PCPI(ENABLE_PCPI),
        .ENABLE_MUL(ENABLE_MULDIV),
        .ENABLE_DIV(ENABLE_MULDIV),
        .ENABLE_IRQ(0),
        .ENABLE_IRQ_QREGS(0)
    ) cpu (
        .clk         (clk_cpu    ),
        .resetn      (resetn     ),
        .mem_valid   (mem_valid  ),
        .mem_instr   (mem_instr  ),
        .mem_ready   (mem_ready  ),
        .mem_addr    (mem_addr   ),
        .mem_wdata   (mem_wdata  ),
        .mem_wstrb   (mem_wstrb  ),
        .mem_rdata   (mem_rdata  ),
        .pcpi_valid  (pcpi_valid ),
        .pcpi_insn   (pcpi_insn  ),
        .pcpi_rs1    (pcpi_rs1   ),
        .pcpi_rs2    (pcpi_rs2   ),
        .pcpi_wr     (1'b1       ),
        .pcpi_rd     (pcpi_rd    ),
        .pcpi_wait   (1'b1       ),
        .pcpi_ready  (pcpi_ready )
    );

    spimemio spimemio (
        .clk    (clk_spi),
        .resetn (resetn),
        .valid  (mem_valid && mem_addr >= 4*MEM_WORDS && mem_addr < 32'h 0200_0000),
        .ready  (spimem_ready),
        .addr   (mem_addr[23:0]),
        .rdata  (spimem_rdata),

        .flash_csb    (flash_csb   ),
        .flash_clk    (flash_clk   ),

        .flash_io0_oe (flash_io0_oe),
        .flash_io1_oe (flash_io1_oe),
        .flash_io2_oe (flash_io2_oe),
        .flash_io3_oe (flash_io3_oe),

        .flash_io0_do (flash_io0_do),
        .flash_io1_do (flash_io1_do),
        .flash_io2_do (flash_io2_do),
        .flash_io3_do (flash_io3_do),

        .flash_io0_di (flash_io0_di),
        .flash_io1_di (flash_io1_di),
        .flash_io2_di (flash_io2_di),
        .flash_io3_di (flash_io3_di)
    );

    ctrlsoc_rxtx rxtx (
        .clk    (clk_cpu),
        .resetn (resetn   ),
        .rx     (ser_rx   ),
        .tx     (ser_tx   ),
        .mem_wvalid (mem_valid && (mem_addr == 32'h 02000008) && |mem_wstrb),
        .mem_rvalid (mem_valid && (mem_addr == 32'h 02000008) && !mem_wstrb),
        .mem_wdata  (mem_wdata),
        .mem_rdata  (rxtx_rdata),
        .mem_ready  (rxtx_ready)
    );

    //
    //  DATA memory
    //

    wire ram_ena = mem_valid & !mem_ready & (mem_addr < 32'h 0002_0000);

    always @(posedge clk_cpu)
        ram_ready <= ram_ena;

    wire [63:0] d_rdata;

    assign ram_rdata = mem_addr[2] ? d_rdata[63:32] : d_rdata[31:0];

    data_mem data_ram (
        .clk   (clk_spi        ),
        .wen   (ram_ena ? mem_wstrb : 4'b0000),
        .addr  (pcpi_valid ? pcpi_rs1[16:0] : mem_addr[16:0]),
        .wdata (mem_wdata      ),
        .rdata (d_rdata        )
    );

    //
    //  COEF memory
    //

    wire coef_ena = mem_valid & !mem_ready & (mem_addr[31:28] == 1);

    always @(posedge clk_cpu)
        coef_ready <= coef_ena;

    wire [127:0] c_rdata;

    assign coef_rdata = mem_addr[3] ? (mem_addr[2] ? c_rdata[127:96] : c_rdata[95:64])
                    : (mem_addr[2] ? c_rdata[ 63:32] : c_rdata[31: 0]);
    coef_mem coef_ram (
        .clk   (clk_spi        ),
        .wen   (coef_ena ? mem_wstrb : 4'b0000),
        .addr  (pcpi_valid ? pcpi_rs2[14:0] : mem_addr[14:0] ),
        .wdata (mem_wdata      ),
        .rdata (c_rdata        )
    );

    //
    //  PCPI rv32 ISA extension
    //

    wire [ 31:0] acc0;
    wire [ 31:0] acc1;
    wire [255:0] dot_mul;

    // FIXME:
    //
    // 1. use OLIMP_VEC_8U8_16I8_2S32 as independent module (alias MACC)
    // 2. flush accumulations into dedicated memory (now is acc0+acc1 for debug)
    // 3. add option to accumulate or not with BIAS (alias MACB)
    // 4. add option to do inplace RELU (alias MACZ)
    //

/*
    // 1 x  8 x uint8
    // 2 x 16 x  int8
    // => 2 x 1 short
    OLIMP_VEC_8U8_16I8_2S32 vec (
        .clk_dsp (clk_spi),
        .data    (d_rdata),
        .coef    (c_rdata),
        .acc0    (acc0),
        .acc1    (acc1)
    );
*/

    MACC_16_16_32 mul [7:0] (
        .clk    (clk_spi),
        .clk_en (1'b1   ),
        .A      ({2{d_rdata}} ),
        .B      (c_rdata      ),
        .X      (dot_mul      )
   );

    // for now do in-place OLIMP_VEC_8U8_16I8_2S32
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
    reg stage = 0;
    // end inplace OLIMP_VEC_8U8_16I8_2S32

    always @(posedge clk_cpu) begin
        //pcpi_rd <= 'bx;
        pcpi_ready <= 0;

        if (pcpi_valid) begin
            case (stage)
                0: begin
                    if (!pcpi_ready) stage <= 1;
                end
                1: begin
                    // ToDo:
                    // for now return summ of summ (debug)
                    // but register it accesible memory
                    pcpi_rd <= acc0 + acc1;
                    pcpi_ready <= 1;

                    stage <= 0;
                end
            endcase

        end
    end

endmodule

module picosoc_regs (
    input clk, wen,
    input [5:0] waddr,
    input [5:0] raddr1,
    input [5:0] raddr2,
    input [31:0] wdata,
    output [31:0] rdata1,
    output [31:0] rdata2
);
    reg [31:0] regs [0:31];

    always @(posedge clk)
        if (wen) regs[waddr[4:0]] <= wdata;

    assign rdata1 = regs[raddr1[4:0]];
    assign rdata2 = regs[raddr2[4:0]];
endmodule
