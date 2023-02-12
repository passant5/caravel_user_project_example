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
 * user_project_wrapper
 *
 * This wrapper enumerates all of the pins available to the
 * user for the user project.
 *
 * An example user project is provided in this wrapper.  The
 * example should be removed and replaced with the actual
 * user project.
 *
 *-------------------------------------------------------------
 */

module user_project_wrapper #(
    parameter BITS = 32
) (
`ifdef USE_POWER_PINS
    inout vdda1,	// User area 1 3.3V supply
    inout vdda2,	// User area 2 3.3V supply
    inout vssa1,	// User area 1 analog ground
    inout vssa2,	// User area 2 analog ground
    inout vccd1,	// User area 1 1.8V supply
    inout vccd2,	// User area 2 1.8v supply
    inout vssd1,	// User area 1 digital ground
    inout vssd2,	// User area 2 digital ground
`endif

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

    // Analog (direct connection to GPIO pad---use with caution)
    // Note that analog I/O is not available on the 7 lowest-numbered
    // GPIO pads, and so the analog_io indexing is offset from the
    // GPIO indexing by 7 (also upper 2 GPIOs do not have analog_io).
    inout [`MPRJ_IO_PADS-10:0] analog_io,

    // Independent clock (on independent integer divider)
    input   user_clock2,

    // User maskable interrupt signals
    output [2:0] user_irq
);

/*--------------------------------------*/
/* User project is instantiated  here   */
/*--------------------------------------*/
    wire [239:0] o_const, const_zero;
    wire [364:0] buf_i, buf_i_q;
    wire clk, user_clk2, rst;

    // For an input, assume the load is that of a high drive strength buffer
// (* keep *)    sky130_fd_sc_hd__clkbuf_16 CLK_BUF[1:0] (
//         `ifdef USE_POWER_PINS
// 			.VGND(vssd1),
// 			.VNB(vssd1),
// 			.VPB(vccd1),
// 			.VPWR(vccd1),
// 		`endif
//         .A({wb_clk_i,user_clock2}), 
//         .X({clk,user_clk2})
//     );
    assign {clk,user_clk2} = {wb_clk_i,user_clock2};
    assign {rst, buf_i} = {wb_rst_i, wbs_cyc_i, wbs_stb_i, wbs_we_i, wbs_sel_i, io_in, la_data_in, la_oenb, wbs_adr_i, wbs_dat_i};
// (* keep *)    sky130_fd_sc_hd__buf_16 i_BUF[365:0] (
//         `ifdef USE_POWER_PINS
// 			.VGND(vssd1),
// 			.VNB(vssd1),
// 			.VPB(vccd1),
// 			.VPWR(vccd1),
// 		`endif
//         .A({wb_rst_i, wbs_cyc_i, wbs_stb_i, wbs_we_i, wbs_sel_i, io_in, la_data_in, la_oenb, wbs_adr_i, wbs_dat_i}), 
//         .X({rst, buf_i})
//     );

    // input transition
(* keep *)    sky130_fd_sc_hd__dfrtp_1 i_FF[364:0] (
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
(* keep *)    sky130_fd_sc_hd__dfrtp_1 user_clk2_FF (
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
// (* keep *)    sky130_fd_sc_hd__buf_2 o_BUF[239:0] (
//         `ifdef USE_POWER_PINS
// 			.VGND(vssd1),
// 			.VNB(vssd1),
// 			.VPB(vccd1),
// 			.VPWR(vccd1),
// 		`endif
//         .A({o_const}), 
//         .X({wbs_ack_o, io_oeb, io_out, user_irq, la_data_out, wbs_dat_o})
//     );

    // output transition
    assign const_zero=240'b0;

(* keep *)    sky130_fd_sc_hd__dfrtp_1 o_FF[239:0] (
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

    assign {wbs_ack_o, io_oeb, io_out, user_irq, la_data_out, wbs_dat_o} = o_const;

endmodule	// user_project_wrapper

`default_nettype wire
