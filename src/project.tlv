\m5_TLV_version 1d: tl-x.org
\m5
   /**
   This template is for developing Tiny Tapeout designs using Makerchip.
   Verilog, SystemVerilog, and/or TL-Verilog can be used.
   Use of Tiny Tapeout Demo Boards (as virtualized in the VIZ tab) is supported.
   See the corresponding Git repository for build instructions.
   **/

   use(m5-1.0)  // See M5 docs in Makerchip IDE Learn menu.

   // ---SETTINGS---
   var(my_design, tt_um_example)  /// Change tt_um_example to tt_um_<your-github-username>_<name-of-your-project>. (See README.md.)
   var(debounce_inputs, 0)
                     /// Legal values:
                     ///   1: Provide synchronization and debouncing on all input signals.
                     ///   0: Don't provide synchronization and debouncing.
                     ///   m5_if_defined_as(MAKERCHIP, 1, 0, 1): Debounce unless in Makerchip.
   // --------------

   // If debouncing, your top module is wrapped within a debouncing module, so it has a different name.
   var(user_module_name, m5_if(m5_debounce_inputs, my_design, m5_my_design))
   var(debounce_cnt, m5_if_defined_as(MAKERCHIP, 1, 8'h03, 8'hff))
\SV
   // Include Tiny Tapeout Lab.
   m4_include_lib(['https:/']['/raw.githubusercontent.com/os-fpga/Virtual-FPGA-Lab/5744600215af09224b7235479be84c30c6e50cb7/tlv_lib/tiny_tapeout_lib.tlv'])

   ///m4_define(['m4_serv_repo'], ['['https://raw.githubusercontent.com/DohJaeger/tt_makerchip_lib/801a9b9f4e7a28094d1ea101b423dd041f4041a9/']'])
   ///m4_define(['m4_serv_rtl'], ['m4_serv_repo['src/uart_rtl/']'])
                                  
   ///m4_sv_get_url(m4_serv_rtl['uart_rx.v'])
   ///m4_sv_get_url(m4_serv_rtl['uart_tx.sv'])

   module uart_tx 
    #(parameter int FREQUENCY = 10000000, parameter int BAUD_RATE = 9600)
    (
        input logic clk,
        input logic reset,
        input logic tx_dv,
        input logic [7:0] tx_byte, 
        output logic tx_active,
        output logic tx_serial,
        output logic tx_done
    );

    typedef enum logic [2:0] {
        s_IDLE          = 3'b000,
        s_TX_START_BIT  = 3'b001,
        s_TX_DATA_BITS  = 3'b010,
        s_TX_STOP_BIT   = 3'b011,
        s_CLEANUP       = 3'b100
    } state_t;

    localparam int CLKS_PER_BIT = FREQUENCY / (16 * BAUD_RATE);

    state_t r_SM_Main = s_IDLE;
    logic [7:0] r_Clock_Count = 0;
    logic [2:0] r_Bit_Index = 0;
    logic [7:0] r_Tx_Data = 0;
    logic r_Tx_Done = 0;
    logic r_Tx_Active = 0;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            r_SM_Main <= s_IDLE;
            r_Clock_Count <= 0;
            r_Bit_Index <= 0;
            r_Tx_Data <= 0;
            r_Tx_Done <= 0;
            r_Tx_Active <= 0;
            tx_serial <= 1;
        end else begin
            case (r_SM_Main)
                s_IDLE: begin
                    tx_serial <= 1; // Line idle state
                    r_Tx_Done <= 0;
                    r_Clock_Count <= 0;
                    r_Bit_Index <= 0;
                    
                    if (tx_dv) begin
                        r_Tx_Active <= 1;
                        r_Tx_Data <= tx_byte;
                        r_SM_Main <= s_TX_START_BIT;
                    end else begin
                        r_SM_Main <= s_IDLE;
                    end
                end

                s_TX_START_BIT: begin
                    tx_serial <= 0; // Start bit
                    if (r_Clock_Count < CLKS_PER_BIT - 1) begin
                        r_Clock_Count <= r_Clock_Count + 1;
                    end else begin
                        r_Clock_Count <= 0;
                        r_SM_Main <= s_TX_DATA_BITS;
                    end
                end

                s_TX_DATA_BITS: begin
                    tx_serial <= r_Tx_Data[r_Bit_Index];
                    if (r_Clock_Count < CLKS_PER_BIT - 1) begin
                        r_Clock_Count <= r_Clock_Count + 1;
                    end else begin
                        r_Clock_Count <= 0;
                        if (r_Bit_Index < 7) begin
                            r_Bit_Index <= r_Bit_Index + 1;
                        end else begin
                            r_Bit_Index <= 0;
                            r_SM_Main <= s_TX_STOP_BIT;
                        end
                    end
                end

                s_TX_STOP_BIT: begin
                    tx_serial <= 1; // Stop bit
                    if (r_Clock_Count < CLKS_PER_BIT - 1) begin
                        r_Clock_Count <= r_Clock_Count + 1;
                    end else begin
                        r_Tx_Done <= 1;
                        r_Clock_Count <= 0;
                        r_Tx_Active <= 0;
                        r_SM_Main <= s_CLEANUP;
                    end
                end

                s_CLEANUP: begin
                    r_Tx_Done <= 1;
                    r_SM_Main <= s_IDLE;
                end

                default: r_SM_Main <= s_IDLE;
            endcase
        end
    end

    assign tx_active = r_Tx_Active;
    assign tx_done = r_Tx_Done;

endmodule


\TLV my_design()
   
   $tx_dv = 1'b1;
   $tx_byte[7:0] = 8'd7;
   
   \SV_plus
      uart_tx #(10000000,9600) uart_tx( .clk(*clk), 
                                         .reset(*reset), 
                                         .tx_dv($tx_dv), 
                                         .tx_byte($tx_byte), 
                                         .tx_active($$tx_active), 
                                         .tx_serial($$tx_serial), 
                                         .tx_done($$tx_done));
                                         
   *uo_out[0] = 1'b0;
   *uo_out[1] = 1'b0;
   *uo_out[2] = $tx_serial;
   *uo_out[3] = 1'b0;
   *uo_out[4] = $tx_active;
   *uo_out[5] = $tx_done;
   *uo_out[6] = 1'b0;
   *uo_out[7] = 1'b0;
   

   // ============================================
   // If you are using TL-Verilog for your design,
   // your TL-Verilog logic goes here.
   // Optionally, provide \viz_js here (for TL-Verilog or Verilog logic).
   // Tiny Tapeout inputs can be referenced as, e.g. *ui_in.
   // (Connect Tiny Tapeout outputs at the end of this template.)
   // ============================================

   // ...

\SV


// ================================================
// A simple Makerchip Verilog test bench driving random stimulus.
// Modify the module contents to your needs.
// ================================================

module top(input logic clk, input logic reset, input logic [31:0] cyc_cnt, output logic passed, output logic failed);
   // Tiny tapeout I/O signals.
   logic [7:0] ui_in, uio_in, uo_out, uio_out, uio_oe;
   logic [31:0] r;
   always @(posedge clk) r = m5_if_defined_as(MAKERCHIP, 1, ['$urandom()'], ['0']);
   assign ui_in = r[7:0];
   assign uio_in = r[15:8];
   logic ena = 1'b0;
   logic rst_n = ! reset;

   /*
   // Or, to provide specific inputs at specific times...
   // BE SURE TO COMMENT THE ASSIGNMENT OF INPUTS ABOVE.
   // BE SURE TO DRIVE THESE ON THE B-PHASE OF THE CLOCK (ODD STEPS).
   // Driving on the rising clock edge creates a race with the clock that has unpredictable simulation behavior.
   initial begin
      #1  // Drive inputs on the B-phase.
         ui_in = 8'h0;
      #10 // Step past reset.
         ui_in = 8'hFF;
      // ...etc.
   end
   */

   // Instantiate the Tiny Tapeout module.
   m5_user_module_name tt(.*);

   assign passed = cyc_cnt > 300;
   assign failed = 1'b0;
endmodule

// Provide a wrapper module to debounce input signals if requested.
m5_if(m5_debounce_inputs, ['m5_tt_top(m5_my_design)'])
// The above macro expands to multiple lines. We enter a new \SV block to reset line tracking.
\SV


// The Tiny Tapeout module.
module m5_user_module_name (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

   wire reset = ! rst_n;

\TLV
   /* verilator lint_off UNOPTFLAT */
   // Connect Tiny Tapeout I/Os to Virtual FPGA Lab.
   m5+tt_connections()

   // Instantiate the Virtual FPGA Lab.
   m5+board(/top, /fpga, 7, $, , my_design)
   // Label the switch inputs [0..7] (1..8 on the physical switch panel) (bottom-to-top).
   m5+tt_input_labels_viz(['"UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED"'])

\SV_plus

   // =========================================
   // If you are using (System)Verilog for your design,
   // your Verilog logic goes here.
   // =========================================

   // ...


   // Connect Tiny Tapeout outputs.
   // Note that my_design will be under /fpga_pins/fpga.
   // Example *uo_out = /fpga_pins/fpga|my_pipe>>3$uo_out;
   //assign *uo_out = 8'b0;
   assign *uio_out = 8'b0;
   assign *uio_oe = 8'b0;

endmodule
