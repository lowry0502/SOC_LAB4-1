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

module user_proj_example #(
    parameter BITS = 32,
    parameter DELAYS=10,
    parameter IDLE = 3'd0,
    parameter STATE_1 = 3'd1,
    parameter STATE_2 = 3'd2,
    parameter STATE_3 = 3'd3,
    parameter STATE_4 = 3'd4
)(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
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

    // IRQ
    output [2:0] irq
);
    wire clk;
    wire rst;

    wire [`MPRJ_IO_PADS-1:0] io_in;
    wire [`MPRJ_IO_PADS-1:0] io_out;
    wire [`MPRJ_IO_PADS-1:0] io_oeb;

    reg [3:0] cnt;
    reg [2:0] curr_state, next_state;
    reg EN0;
    reg [31:0] addr;
    reg ack_reg;
    wire valid;
    wire [3:0] wstrb;

    assign clk = wb_clk_i;
    assign rst = wb_rst_i;
    assign valid = wbs_cyc_i && wbs_stb_i; 
    assign wstrb = wbs_sel_i & {4{wbs_we_i}};
    assign wbs_ack_o = ack_reg;

    always @(posedge clk or negedge rst) begin
        if(rst) begin
            curr_state <= IDLE;
        end
        else begin
            curr_state <= next_state;
            if(curr_state == IDLE) begin
                cnt <= DELAYS - 3;
                ack_reg <= 0;
                EN0 <= 0;
            end
            else if(curr_state == STATE_1) begin
                cnt <= cnt - 1;
                if(cnt == 4'd0) begin
                    EN0 <= 1;
                    addr <= (wbs_adr_i - 32'h3800_0000)>>2;
                end
            end
            else if(curr_state == STATE_2) begin
                
            end
            else if(curr_state == STATE_3) begin
                ack_reg <= 1;
            end
            else if(curr_state == STATE_4) begin
                ack_reg <= 0;
                EN0 <= 0;
            end
            else begin
            end
        end
    end
    always @(*) begin
        next_state = 3'dx;
        case(curr_state)
            IDLE: 
                if(valid & wbs_adr_i >= 32'h3800_0000)
                    next_state = STATE_1;
                else
                    next_state = IDLE;
            STATE_1:
                if(cnt == 4'd0)
                    next_state = STATE_2;
                else
                    next_state = STATE_1;
            STATE_2:
                next_state = STATE_3;
            STATE_3:
                next_state = STATE_4;
            STATE_4:
                next_state = IDLE;
        endcase
    end

    bram user_bram (
        .CLK(clk),
        .WE0(wstrb),
        .EN0(EN0),
        .Di0(wbs_dat_i),
        .Do0(wbs_dat_o),
        .A0(addr)
    );

endmodule


`default_nettype wire
