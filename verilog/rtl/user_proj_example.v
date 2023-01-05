// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
/*
 *-------------------------------------------------------------
 *
 * user_proj_example
 *
 * This is an example of a (trivially simple) user project,
 * showing how the user project can connect to the logic
 * analyzer, the wishbone bus, and the I/O pads.
 *
 * This project generates an integer count, which is output
 * on the user area GPIO pads (digital output only).  The
 * wishbone connection allows the project to be controlled
 * (start and stop) from the management SoC program.
 *
 * See the testbenches in directory "mprj_counter" for the
 * example programs that drive this user project.  The three
 * testbenches are "io_ports", "la_test1", and "la_test2".
 *
 *-------------------------------------------------------------
 */

module user_proj_example (
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif
    input user_clock2,
    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // IRQ
    output [2:0] irq
);
    wire [239:0] o_const, const_zero;
    wire [364:0] buf_i, buf_i_q;
    wire clk, user_clk2, rst;

    // For an input, assume the load is that of a high drive strength buffer
    sky130_fd_sc_hd__clkbuf_16 CLK_BUF[1:0] (
        `ifdef USE_POWER_PINS
			.VGND(vssd1),
			.VNB(vssd1),
			.VPB(vccd1),
			.VPWR(vccd1),
		`endif
        .A({wb_clk_i,user_clock2}), 
        .X({clk,user_clk2})
    );

    sky130_fd_sc_hd__buf_16 i_BUF[365:0] (
        `ifdef USE_POWER_PINS
			.VGND(vssd1),
			.VNB(vssd1),
			.VPB(vccd1),
			.VPWR(vccd1),
		`endif
        .A({wb_rst_i, wbs_cyc_i, wbs_stb_i, wbs_we_i, wbs_sel_i, io_in, la_data_in, la_oenb, wbs_adr_i, wbs_dat_i}), 
        .X({rst, buf_i})
    );

    // input transition
    sky130_fd_sc_hd__dfrtp_1 i_FF[364:0] (
        `ifdef USE_POWER_PINS
			.VGND(vssd1),
			.VNB(vssd1),
			.VPB(vccd1),
			.VPWR(vccd1),
		`endif
        .CLK(clk),
        .D(buf_i),
        .Q(buf_i_q),
        .RESET_B(rst)
    );

    wire user_clk2_test, user_clk2_test_q;
    assign user_clk2_test = wbs_we_i;
    sky130_fd_sc_hd__dfrtp_1 user_clk2_FF (
        `ifdef USE_POWER_PINS
			.VGND(vssd1),
			.VNB(vssd1),
			.VPB(vccd1),
			.VPWR(vccd1),
		`endif
        .CLK(user_clk2),
        .D(user_clk2_test),
        .Q(user_clk2_test_q),
        .RESET_B(rst)
    );

    // For an output, assume the drive capability is that of a low drive strength buffer 
    sky130_fd_sc_hd__buf_2 o_BUF[239:0] (
        `ifdef USE_POWER_PINS
			.VGND(vssd1),
			.VNB(vssd1),
			.VPB(vccd1),
			.VPWR(vccd1),
		`endif
        .A({o_const}), 
        .X({wbs_ack_o, io_oeb, io_out, irq, la_data_out, wbs_dat_o})
    );

    // output transition
    assign const_zero=240'b0;

    sky130_fd_sc_hd__dfrtp_1 o_FF[239:0] (
        `ifdef USE_POWER_PINS
			.VGND(vssd1),
			.VNB(vssd1),
			.VPB(vccd1),
			.VPWR(vccd1),
		`endif
        .CLK(clk),
        .D(const_zero),
        .Q(o_const),
        .RESET_B(rst)
    );
endmodule
`default_nettype wire
