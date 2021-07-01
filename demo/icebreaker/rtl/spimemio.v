/*
 *  Serial Protocol Interface (SPI) memory I/O
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

/*
 * QSPI flash memory:
 *   DDR double data rate
 *   QUAD (x4) bus data access
 *   Continuous address increment
 *   QPI short command mode (optional)
 *
 */



// enable QPI mode
// Warning: IceBreaker flash
// module will remain in QPI mode
//
//`define QPI 1

module spimemio (
    input clk, resetn,

    input valid,
    output ready,
    input [23:0] addr,
    output reg [31:0] rdata,

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
    reg        xfer_resetn;
    reg        din_valid;
    wire       din_ready;
    reg  [7:0] din_data;
    reg  [3:0] din_tag;
`ifdef QPI
    reg        din_qpi;
`endif
    reg        din_qspi;
    reg        din_rd;

    wire       dout_valid;
    wire [7:0] dout_data;
    wire [3:0] dout_tag;

    reg [23:0] buffer;

    reg [23:0] rd_addr;
    reg rd_valid;
    reg rd_wait;
    reg rd_inc;

    assign ready = valid && (addr == rd_addr) && rd_valid;
    wire jump = valid && !ready && (addr != rd_addr+4) && rd_valid;

    wire xfer_csb;
    wire xfer_clk;

    wire xfer_io0_oe;
    wire xfer_io1_oe;
    wire xfer_io2_oe;
    wire xfer_io3_oe;

    wire xfer_io0_do;
    wire xfer_io1_do;
    wire xfer_io2_do;
    wire xfer_io3_do;

    reg xfer_io0_90;
    reg xfer_io1_90;
    reg xfer_io2_90;
    reg xfer_io3_90;

    always @(negedge clk) begin
        xfer_io0_90 <= xfer_io0_do;
        xfer_io1_90 <= xfer_io1_do;
        xfer_io2_90 <= xfer_io2_do;
        xfer_io3_90 <= xfer_io3_do;
    end

    assign flash_csb = xfer_csb;
    assign flash_clk = xfer_clk;

    assign flash_io0_oe = xfer_io0_oe;
    assign flash_io1_oe = xfer_io1_oe;
    assign flash_io2_oe = xfer_io2_oe;
    assign flash_io3_oe = xfer_io3_oe;

    assign flash_io0_do = xfer_io0_90;
    assign flash_io1_do = xfer_io1_90;
    assign flash_io2_do = xfer_io2_90;
    assign flash_io3_do = xfer_io3_90;

    spimemio_xfer xfer (
        .clk          (clk         ),
        .resetn       (xfer_resetn ),
        .din_valid    (din_valid   ),
        .din_ready    (din_ready   ),
        .din_data     (din_data    ),
        .din_tag      (din_tag     ),
`ifdef QPI
        .din_qpi      (din_qpi     ),
`endif
        .din_qspi     (din_qspi    ),
        .din_rd       (din_rd      ),
        .dout_valid   (dout_valid  ),
        .dout_data    (dout_data   ),
        .dout_tag     (dout_tag    ),
        .flash_csb    (xfer_csb    ),
        .flash_clk    (xfer_clk    ),
        .flash_io0_oe (xfer_io0_oe ),
        .flash_io1_oe (xfer_io1_oe ),
        .flash_io2_oe (xfer_io2_oe ),
        .flash_io3_oe (xfer_io3_oe ),
        .flash_io0_do (xfer_io0_do ),
        .flash_io1_do (xfer_io1_do ),
        .flash_io2_do (xfer_io2_do ),
        .flash_io3_do (xfer_io3_do ),
        .flash_io0_di (flash_io0_di),
        .flash_io1_di (flash_io1_di),
        .flash_io2_di (flash_io2_di),
        .flash_io3_di (flash_io3_di)
    );

    reg [3:0] state;

    always @(posedge clk) begin
        xfer_resetn <= 1;
        din_valid <= 0;

        if (!resetn) begin
            state <= 0;
            xfer_resetn <= 0;
            rd_valid <= 0;
            din_tag <= 0;
`ifdef QPI
            din_qpi <= 0;
`endif
            din_qspi <= 0;
            din_rd <= 0;
        end else begin
            if (dout_valid && dout_tag == 1) buffer[ 7: 0] <= dout_data;
            if (dout_valid && dout_tag == 2) buffer[15: 8] <= dout_data;
            if (dout_valid && dout_tag == 3) buffer[23:16] <= dout_data;
            if (dout_valid && dout_tag == 4) begin
                rdata <= {dout_data, buffer};
                rd_addr <= rd_inc ? rd_addr + 4 : addr;
                rd_valid <= 1;
                rd_wait <= rd_inc;
                rd_inc <= 1;
            end

            if (valid)
                rd_wait <= 0;

            case (state)
                0: begin
                    din_valid <= 1;
                    din_data <= 8'h 66;
                    din_tag <= 0;
                    if (din_ready) begin
                        din_valid <= 0;
                        state <= 1;
                    end
                end
                1: begin
                    if (dout_valid) begin
                        xfer_resetn <= 0;
                        state <= 2;
                    end
                end
                2: begin
                    din_valid <= 1;
                    din_data <= 8'h 99;
                    din_tag <= 0;
                    if (din_ready) begin
                        din_valid <= 0;
                        state <= 3;
                    end
                end
                3: begin
                    if (dout_valid) begin
                        xfer_resetn <= 0;
`ifdef QPI
                        state <= 4;
`else
                        state <= 6;
`endif
                    end
                end
`ifdef QPI
                4: begin
                    din_valid <= 1;
                    din_data <= 8'h 38;
                    din_tag <= 0;
                    if (din_ready) begin
                        din_valid <= 0;
                        state <= 5;
                    end
                end
                5: begin
                    if (dout_valid) begin
                        xfer_resetn <= 0;
                        state <= 6;
                    end
                end
`endif
                6: begin
                    rd_inc <= 0;
                    din_valid <= 1;
                    din_tag <= 0;
                    din_data <= 8'h ED;
`ifdef QPI
                    din_qspi <= 1;
                    din_qpi <= 1;
`endif
                    if (din_ready) begin
                        din_valid <= 0;
                        state <= 7;
                    end
                end
                7: begin
                    if (valid && !ready) begin
                        din_valid <= 1;
                        din_tag <= 0;
                        din_data <= addr[23:16];
`ifdef QPI
                        din_qpi  <= 0;
`endif
                        din_qspi <= 1;
                        if (din_ready) begin
                            din_valid <= 0;
                            state <= 8;
                        end
                    end
                end
                8: begin
                    din_valid <= 1;
                    din_tag <= 0;
                    din_data <= addr[15:8];
                    if (din_ready) begin
                        din_valid <= 0;
                        state <= 9;
                    end
                end
                9: begin
                    din_valid <= 1;
                    din_tag <= 0;
                    din_data <= addr[7:0];
                    if (din_ready) begin
                        din_valid <= 0;
                        din_data <= 0;
                        state <= 10;
                    end
                end
                10: begin
                    din_valid <= 1;
                    din_tag <= 0;
                    din_data <= 8'h A5;
                    if (din_ready) begin
                        din_rd <= 1;
                        din_data <= 7;
                        din_valid <= 0;
                        state <= 11;
                    end
                end
                11: begin
                    din_valid <= 1;
                    din_tag <= 1;
                    if (din_ready) begin
                        din_valid <= 0;
                        state <= 12;
                    end
                end
                12: begin
                    din_valid <= 1;
                    din_data <= 8'h 00;
                    din_tag <= 2;
                    if (din_ready) begin
                        din_valid <= 0;
                        state <= 13;
                    end
                end
                13: begin
                    din_valid <= 1;
                    din_tag <= 3;
                    if (din_ready) begin
                        din_valid <= 0;
                        state <= 14;
                    end
                end
                14: begin
                    if (!rd_wait || valid) begin
                        din_valid <= 1;
                        din_tag <= 4;
                        if (din_ready) begin
                            din_valid <= 0;
                            state <= 11;
                        end
                    end
                end
            endcase

            if (jump) begin
                rd_inc <= 0;
                rd_valid <= 0;
                xfer_resetn <= 0;
                state <= 7;
                din_rd <= 0;
            end
        end
    end
endmodule

module spimemio_xfer (
    input clk, resetn,

    input            din_valid,
    output           din_ready,
    input      [7:0] din_data,
    input      [3:0] din_tag,
`ifdef QPI
    input            din_qpi,
`endif
    input            din_qspi,
    input            din_rd,

    output           dout_valid,
    output     [7:0] dout_data,
    output     [3:0] dout_tag,

    output reg flash_csb,
    output reg flash_clk,

    output reg flash_io0_oe,
    output reg flash_io1_oe,
    output reg flash_io2_oe,
    output reg flash_io3_oe,

    output reg flash_io0_do,
    output reg flash_io1_do,
    output reg flash_io2_do,
    output reg flash_io3_do,

    input      flash_io0_di,
    input      flash_io1_di,
    input      flash_io2_di,
    input      flash_io3_di
);

    reg [7:0] obuffer;
    reg [7:0] ibuffer;

    reg [3:0] count;
    reg [3:0] dummy_count;

`ifdef QPI
    reg xfer_qpi;
`endif
    reg xfer_qspi;
    reg xfer_ddr;
    reg xfer_ddr_q;
    reg xfer_rd;
    reg [3:0] xfer_tag;
    reg [3:0] xfer_tag_q;

    reg [7:0] next_obuffer;
    reg [7:0] next_ibuffer;
    reg [3:0] next_count;

    reg fetch;
    reg next_fetch;
    reg last_fetch;

    always @(posedge clk) begin
        xfer_ddr_q <= xfer_ddr;
        xfer_tag_q <= xfer_tag;
    end

    assign din_ready = din_valid && resetn && next_fetch;

    assign dout_valid = (xfer_ddr_q ? fetch && !last_fetch : next_fetch && !fetch) && resetn;
    assign dout_data = ibuffer;
    assign dout_tag = xfer_tag_q;

    always @* begin
        flash_io0_oe = 0;
        flash_io1_oe = 0;
        flash_io2_oe = 0;
        flash_io3_oe = 0;

        flash_io0_do = 0;
        flash_io1_do = 0;
        flash_io2_do = 0;
        flash_io3_do = 0;

        next_obuffer = obuffer;
        next_ibuffer = ibuffer;
        next_count = count;
        next_fetch = 0;

        if (dummy_count == 0) begin
            // SPI serial
            if (xfer_qspi == 0) begin
                flash_io0_oe = 1;
                flash_io0_do = obuffer[7];

                if (flash_clk) begin
                    next_obuffer = {obuffer[6:0], 1'b 0};
                    next_count = count - |count;
                end else begin
                    next_ibuffer = {ibuffer[6:0], flash_io1_di};
                end
            end
            // QSPI serial
            else begin
                flash_io0_oe = !xfer_rd;
                flash_io1_oe = !xfer_rd;
                flash_io2_oe = !xfer_rd;
                flash_io3_oe = !xfer_rd;
                flash_io0_do = obuffer[4];
                flash_io1_do = obuffer[5];
                flash_io2_do = obuffer[6];
                flash_io3_do = obuffer[7];
`ifdef QPI
                // QPI command mode
                if (xfer_qpi) begin
                    if (flash_clk) begin
                        next_obuffer = {obuffer[3:0], 4'b 0000};
                        next_count = count - {|count, 2'b 00};
                    end else begin
                        next_ibuffer = {ibuffer[3:0], flash_io3_di, flash_io2_di, flash_io1_di, flash_io0_di};
                    end
                end
                else begin
`endif
                    next_obuffer = {obuffer[3:0], 4'b 0000};
                    next_count = count - {|count, 2'b 00};
                    next_ibuffer = {ibuffer[3:0], flash_io3_di, flash_io2_di, flash_io1_di, flash_io0_di};
`ifdef QPI
                end
`endif
            end

            next_fetch = (next_count == 0);
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            fetch <= 1;
            last_fetch <= 1;
            flash_csb <= 1;
            flash_clk <= 0;
            count <= 0;
            dummy_count <= 0;
            xfer_tag <= 0;
`ifdef QPI
            xfer_qpi <= 0;
`endif
            xfer_qspi <= 0;
            xfer_ddr <= 0;
            xfer_rd <= 0;
        end else begin
            fetch <= next_fetch;
            last_fetch <= xfer_ddr ? fetch : 1;
            if (dummy_count) begin
                flash_clk <= !flash_clk && !flash_csb;
                dummy_count <= dummy_count - flash_clk;
            end else
            if (count) begin
                flash_clk <= !flash_clk && !flash_csb;
                obuffer <= next_obuffer;
                ibuffer <= next_ibuffer;
                count <= next_count;
            end
            if (din_valid && din_ready) begin
                flash_csb <= 0;
                flash_clk <= 0;

                count <= 8;
                dummy_count <= din_rd ? din_data : 0;
                obuffer <= din_data;

                xfer_tag <= din_tag;
                xfer_qspi <= din_qspi;
`ifdef QPI
                xfer_qpi <= din_qpi;
                xfer_ddr <= din_qpi ? 0 : din_qspi;
`else
                xfer_ddr <= din_qspi;
`endif
                xfer_rd <= din_rd;
            end
        end
    end
endmodule
