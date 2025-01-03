\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
   
   
   // ########################################################
   // #                                                      #
   // #  Empty template for Tiny Tapeout Makerchip Projects  #
   // #                                                      #
   // ########################################################
   
   // ========
   // Settings
   // ========
   
   //-------------------------------------------------------
   // Build Target Configuration
   //
   var(my_design, tt_um_example)   /// The name of your top-level TT module, to match your info.yml.
   var(target, ASIC)   /// Note, the FPGA CI flow will set this to FPGA.
   //-------------------------------------------------------
   
   var(in_fpga, 1)   /// 1 to include the demo board. (Note: Logic will be under /fpga_pins/fpga.)
   var(debounce_inputs, 0)         /// 1: Provide synchronization and debouncing on all input signals.
                                   /// 0: Don't provide synchronization and debouncing.
                                   /// m5_if_defined_as(MAKERCHIP, 1, 0, 1): Debounce unless in Makerchip.
   
   // ======================
   // Computed From Settings
   // ======================
   
   // If debouncing, a user's module is within a wrapper, so it has a different name.
   var(user_module_name, m5_if(m5_debounce_inputs, my_design, m5_my_design))
   var(debounce_cnt, m5_if_defined_as(MAKERCHIP, 1, 8'h03, 8'hff))
   // No TT lab outside of Makerchip.
   if_defined_as(MAKERCHIP, 1, [''], ['m5_set(in_fpga, 0)'])
\SV
   // Include Tiny Tapeout Lab.
   m4_include_lib(['https:/']['/raw.githubusercontent.com/os-fpga/Virtual-FPGA-Lab/5744600215af09224b7235479be84c30c6e50cb7/tlv_lib/tiny_tapeout_lib.tlv'])


\TLV my_design()
   
   |uart
      @0
         /*
         // IDLE -> 2'd0
         // S1 -> 2'd1
         // S2 -> 2'd2
         
         \SV_plus
            localparam IDLE    = 2'b00;
            localparam STATE_1 = 2'b01;
            localparam STATE_2 = 2'b10;
         
         $reset = *reset;
         $cur_state[1:0] = $reset ? 2'd0 :
                      >>1$next_state;
         
         $input_signal = *ui_in[0];
         $next_state[1:0] = ($cur_state == *IDLE && $input_signal) ? *STATE_1 :
                      ($cur_state == *STATE_1 && !$input_signal) ? *STATE_2 :
                      ($cur_state == *STATE_1) ? *IDLE :
                      *IDLE;
         */
         
         $tx_dv = *ui_in[7];
         $tx_byte[7:0] = {1'b0, *ui_in[6:0]};
         //$tx_dv = 1'b1;
         //$tx_byte[7:0] = 8'd85;
         
         \SV_plus
            localparam IDLE = 3'd0;
            localparam TX_START_BIT = 3'd1;
            localparam TX_DATA_BITS = 3'd2;
            localparam TX_STOP_BIT = 3'd3;
            localparam CLEANUP = 3'd4;
            localparam FREQUENCY = 20_000_000;
         
            localparam BAUD_RATE = 115200;
            localparam CLKS_PER_BIT = 174;
         
         $reset = *reset;
         $cur_state[2:0] = $reset ? *IDLE :
                           >>1$next_state;
         
         $next_state[2:0] = *reset ? *IDLE :
                            ($cur_state == *IDLE && $tx_dv) ? *TX_START_BIT :
                            (($cur_state == *TX_START_BIT) && ($clk_cnt[7:0] == *CLKS_PER_BIT - 1'b1)) ? *TX_DATA_BITS :
                            (($cur_state == *TX_DATA_BITS) && ($clk_cnt[7:0] == *CLKS_PER_BIT - 1'b1) && ($bit_index[2:0] == 3'd7)) ? *TX_STOP_BIT :
                            (($cur_state == *TX_DATA_BITS) && ($clk_cnt[7:0] == *CLKS_PER_BIT - 1)) ? *TX_DATA_BITS :
                            (($cur_state == *TX_STOP_BIT) && ($clk_cnt[7:0] == *CLKS_PER_BIT - 1)) ? *CLEANUP :
                            ($cur_state == *CLEANUP) ? *IDLE :
                            $cur_state;
         
         $clk_cnt[7:0] = *reset ? 0 :
                         (($cur_state == *IDLE) || (>>1$clk_cnt == *CLKS_PER_BIT - 1)) ? 0 :
                         (>>1$clk_cnt + 1);
         
         $bit_index[2:0] = *reset ? 0 :
                           (($cur_state == *TX_DATA_BITS) && ($clk_cnt == *CLKS_PER_BIT - 1) && (>>1$bit_index < 7)) ? (>>1$bit_index + 1) :
                           >>1$bit_index;
         
         $tx_data[7:0] = *reset ? 0 :
                         ($cur_state == *IDLE && $tx_dv) ? $tx_byte[7:0] :
                         >>1$tx_data;
         
         $tx_serial = *reset ? 1 :
                      ($cur_state == *TX_START_BIT) ? 0 :              // Start bit
                      ($cur_state == *TX_DATA_BITS) ? $tx_data[$bit_index] : // Data bits
                      ($cur_state == *TX_STOP_BIT) ? 1 :              // Stop bit
                      1;
         
         $tx_done = *reset ? 0 :
                    ($cur_state == *CLEANUP) ? 1 :
                    0;
         
         $tx_active = *reset ? 0 :
                      ($cur_state == *TX_START_BIT || $cur_state == *TX_DATA_BITS || $cur_state == *TX_STOP_BIT) ? 1 : 
                      0;
         
         *uo_out[0] = $tx_active;
         *uo_out[1] = $tx_done;
         *uo_out[5] = $tx_serial;
   
   // Note that pipesignals assigned here can be found under /fpga_pins/fpga.
   
   
   
   
   // Connect Tiny Tapeout outputs. Note that uio_ outputs are not available in the Tiny-Tapeout-3-based FPGA boards.
   //*uo_out = 8'b0;
   m5_if_neq(m5_target, FPGA, ['*uio_out = 8'b0;'])
   m5_if_neq(m5_target, FPGA, ['*uio_oe = 8'b0;'])

// Set up the Tiny Tapeout lab environment.
\TLV tt_lab()
   // Connect Tiny Tapeout I/Os to Virtual FPGA Lab.
   m5+tt_connections()
   // Instantiate the Virtual FPGA Lab.
   m5+board(/top, /fpga, 7, $, , my_design)
   // Label the switch inputs [0..7] (1..8 on the physical switch panel) (top-to-bottom).
   m5+tt_input_labels_viz(['"UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED"'])

\SV

// ================================================
// A simple Makerchip Verilog test bench driving random stimulus.
// Modify the module contents to your needs.
// ================================================

module top(input logic clk, input logic reset, input logic [31:0] cyc_cnt, output logic passed, output logic failed);
   // Tiny tapeout I/O signals.
   logic [7:0] ui_in, uo_out;
   m5_if_neq(m5_target, FPGA, ['logic [7:0] uio_in, uio_out, uio_oe;'])
   logic [31:0] r;  // a random value
   always @(posedge clk) r <= m5_if_defined_as(MAKERCHIP, 1, ['$urandom()'], ['0']);
   assign ui_in = r[7:0];
   m5_if_neq(m5_target, FPGA, ['assign uio_in = 8'b0;'])
   logic ena = 1'b0;
   logic rst_n = ! reset;
   
   /*
   // Or, to provide specific inputs at specific times (as for lab C-TB) ...
   // BE SURE TO COMMENT THE ASSIGNMENT OF INPUTS ABOVE.
   // BE SURE TO DRIVE THESE ON THE B-PHASE OF THE CLOCK (ODD STEPS).
   // Driving on the rising clock edge creates a race with the clock that has unpredictable simulation behavior.
   initial begin
      #1  // Drive inputs on the B-phase.
         ui_in = 8'h0;
      #10 // Step 5 cycles, past reset.
         ui_in = 8'hFF;
      // ...etc.
   end
   */

   // Instantiate the Tiny Tapeout module.
   m5_my_design tt(.*);
   
   assign passed = top.cyc_cnt > 800;
   assign failed = 1'b0;
endmodule


// Provide a wrapper module to debounce input signals if requested.
m5_if(m5_debounce_inputs, ['m5_tt_top(m5_my_design)'])
\SV



// =======================
// The Tiny Tapeout module
// =======================

module m5_user_module_name (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
    m5_if_eq(m5_target, FPGA, ['/']['*'])   // The FPGA is based on TinyTapeout 3 which has no bidirectional I/Os (vs. TT6 for the ASIC).
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    m5_if_eq(m5_target, FPGA, ['*']['/'])
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
   wire reset = ! rst_n;

   // List all potentially-unused inputs to prevent warnings
   (* keep *) wire _unused = &{ena, clk, reset, ui_in, uio_in, 1'b1};

\TLV
   /* verilator lint_off UNOPTFLAT */
   m5_if(m5_in_fpga, ['m5+tt_lab()'], ['m5+my_design()'])

\SV_plus
   
   // ==========================================
   // If you are using Verilog for your design,
   // your Verilog logic goes here.
   // Note, output assignments are in my_design.
   // ==========================================

\SV
endmodule
