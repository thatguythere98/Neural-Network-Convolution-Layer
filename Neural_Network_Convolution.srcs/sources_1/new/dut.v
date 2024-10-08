`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:        Your Company Name
// Engineer:       Your Name
//
// Create Date:    MM/DD/YYYY
// Design Name:    MyDesign
// Module Name:    MyDesign
// Project Name:   Neural_Network_Convolution
// Target Devices: Xilinx 7-Series FPGAs (Artix-7, Kintex-7, Virtex-7)
// Tool Versions:  Vivado 2024.1
//
// Description:
// This module implements a state machine that reads input data and weights
// from various SRAMs, performs a series of convolutions or multiplications,
// and writes the computed results back to an output SRAM. The module includes
// multiple stages for reading data, computing, and writing output, and supports
// a ReLU activation function.
//
// Dependencies:
// None
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// - Ensure the SRAM interface timing and address space match your specific
//   hardware configuration.
// - This module is designed for convolution-like operations with a ReLU activation.
//
/////////////////////////////////////////////////////////////////////////////////

module MyDesign (
    //---------------------------------------------------------------------------
    // Control Signals
    input   wire dut_run                    ,   // Start signal for the DUT (Design Under Test)
    output  reg  dut_busy                   ,   // Busy flag indicating operation in progress
    input   wire reset_b                    ,   // Active-low reset signal
    input   wire clk                        ,   // Clock signal

    //---------------------------------------------------------------------------
    // Input SRAM Interface
    output reg        input_sram_write_enable    ,   // Write enable for input SRAM
    output reg [11:0] input_sram_write_addresss  ,   // Write address for input SRAM
    output reg [15:0] input_sram_write_data      ,   // Data to write to input SRAM
    output reg [11:0] input_sram_read_address    ,   // Read address for input SRAM
    input  wire [15:0] input_sram_read_data      ,   // Data read from input SRAM

    //---------------------------------------------------------------------------
    // Output SRAM Interface
    output reg        output_sram_write_enable    ,   // Write enable for output SRAM
    output reg [11:0] output_sram_write_addresss  ,   // Write address for output SRAM
    output reg [15:0] output_sram_write_data      ,   // Data to write to output SRAM
    output reg [11:0] output_sram_read_address    ,   // Read address for output SRAM
    input  wire [15:0] output_sram_read_data      ,   // Data read from output SRAM

    //---------------------------------------------------------------------------
    // Scratchpad SRAM Interface
    output reg        scratchpad_sram_write_enable    ,   // Write enable for scratchpad SRAM
    output reg [11:0] scratchpad_sram_write_addresss  ,   // Write address for scratchpad SRAM
    output reg [15:0] scratchpad_sram_write_data      ,   // Data to write to scratchpad SRAM
    output reg [11:0] scratchpad_sram_read_address    ,   // Read address for scratchpad SRAM
    input  wire [15:0] scratchpad_sram_read_data      ,   // Data read from scratchpad SRAM

    //---------------------------------------------------------------------------
    // Weights SRAM Interface
    output reg        weights_sram_write_enable    ,   // Write enable for weights SRAM
    output reg [11:0] weights_sram_write_addresss  ,   // Write address for weights SRAM
    output reg [15:0] weights_sram_write_data      ,   // Data to write to weights SRAM
    output reg [11:0] weights_sram_read_address    ,   // Read address for weights SRAM
    input  wire [15:0] weights_sram_read_data         // Data read from weights SRAM

  );

  //---------------------------------------------------------------------------
  // State Machine Declarations
  parameter STATE_IDLE         = 4'b0000;  // Idle state, waiting for 'dut_run' to assert
  parameter STATE_READ_WEIGHT  = 4'b0001;  // State to read weights from SRAM
  parameter STATE_SAVE_WEIGHT  = 4'b0010;  // State to store weights in internal buffer

  parameter STATE_READ_INPUT_1 = 5'd3;     // First input read state
  parameter STATE_READ_INPUT_2 = 5'd4;     // Second input read state
  parameter STATE_READ_INPUT_3 = 5'd5;     // Third input read state
  parameter STATE_READ_INPUT_4 = 5'd6;     // Fourth input read state
  parameter STATE_READ_INPUT_5 = 5'd7;     // Fifth input read state
  parameter STATE_READ_INPUT_6 = 5'd8;     // Sixth input read state
  parameter STATE_READ_INPUT_7 = 5'd9;     // Seventh input read state
  parameter STATE_READ_INPUT_8 = 5'd10;    // Eighth input read state
  parameter STATE_READ_INPUT_9 = 5'd11;    // Ninth input read state
  parameter STATE_COMPUTE_OUTPUT = 5'd12;  // State for computing output
  parameter STATE_WRITE_OUTPUT  = 5'd13;   // State for writing computed output to SRAM

  //---------------------------------------------------------------------------
  // Internal Registers
  reg  [5:0] current_state = STATE_IDLE;  // Current state of the state machine

  reg signed [15:0] input_buffer [5:0];   // Buffer for storing input data
  wire signed [7:0] processed_input [17:0]; // Processed input after splitting 16-bit into 8-bit

  reg signed [7:0] weight_buffer [9:0];   // Buffer for storing weights

  wire signed [15:0] multiplied_results [8:0];  // Multiplication results for first set of inputs
  wire signed [15:0] multiplied_results2[8:0];  // Multiplication results for second set of inputs

  wire signed [19:0] final_output;        // Summed output from the first set of multiplications
  wire signed [19:0] final_output2;       // Summed output from the second set of multiplications

  reg signed [15:0] relu_output;          // ReLU applied result for the final output

  // Address and Counter Registers
  reg [11:0] input_address, weight_address, output_address; // Addresses for SRAM
  reg [10:0] row_counter;                                   // Row counter for input data

  //---------------------------------------------------------------------------
  // State Machine Logic
  always @(posedge clk)
  begin
    if (~reset_b)
    begin  // Active-low reset logic
      // Reset all control signals and addresses
      dut_busy <= 1'b0;
      weights_sram_write_enable <= 1'b0;
      weights_sram_read_address <= 12'b0;
      input_sram_write_enable <= 1'b0;
      input_sram_read_address <= 12'b0;
      output_sram_write_enable <= 1'b0;
      output_sram_write_addresss <= 12'b0;
      output_sram_write_data <= 16'b0;
      input_address <= 12'b0;
      weight_address <= 12'b0;
      output_address <= 12'b0;
      row_counter <= 10'd0;

    end
    else
    begin
      case (current_state)
        //---------------------------------------------------------------------------
        // IDLE State
        STATE_IDLE:
        begin
          if (dut_run)
          begin
            // Start operation when 'dut_run' is asserted
            current_state <= STATE_READ_WEIGHT;
            weights_sram_write_addresss <= 1'b0;
            weights_sram_read_address <= 12'b0;
            input_sram_write_enable <= 1'b0;
            input_sram_read_address <= 12'b0;
            output_sram_write_enable <= 1'b0;
            output_sram_write_addresss <= 12'b0;
            output_sram_write_data <= 16'b0;
            input_address <= 12'b0;
            weight_address <= 12'b0;
            output_address <= 12'b0;
          end
          else
          begin
            current_state <= STATE_IDLE;  // Stay in IDLE if 'dut_run' is not asserted
            dut_busy <= 1'b0;
          end
        end

        //---------------------------------------------------------------------------
        // Read weights from SRAM
        STATE_READ_WEIGHT:
        begin
          dut_busy <= 1'b1;
          current_state <= STATE_SAVE_WEIGHT;
          weights_sram_write_enable <= 1'b0;
          weights_sram_read_address <= weight_address;  // Set address to read weight
          weight_address <= weight_address + 1'b1;      // Increment weight address
        end

        //---------------------------------------------------------------------------
        // Save weights into internal buffer
        STATE_SAVE_WEIGHT:
        begin
          if (weight_address > 0)
          begin
            // Store two weights into the weight buffer
            {weight_buffer[(weights_sram_read_address*2)-2'd2], weight_buffer[(weights_sram_read_address*2)-2'd1]} <= weights_sram_read_data;
          end

          if (weight_address > 5)
          begin
            // If all weights are read, move to input read state
            current_state <= STATE_READ_INPUT_1;
          end
          else
          begin
            // Continue reading weights
            current_state <= STATE_READ_WEIGHT;
          end
        end

        //---------------------------------------------------------------------------
        // Reading input data from Input SRAM in stages
        STATE_READ_INPUT_1:
        begin
          current_state <= STATE_READ_INPUT_2;
          output_sram_write_enable <= 1'b0;
          input_sram_write_enable <= 1'b0;
          input_sram_read_address <= input_address;
        end
        STATE_READ_INPUT_2:
        begin
          current_state <= STATE_READ_INPUT_3;
          input_sram_read_address <= input_address + 1'd1;
        end
        STATE_READ_INPUT_3:
        begin
          current_state <= STATE_READ_INPUT_4;
          input_sram_read_address <= input_address + 5'd8;
          input_buffer[0] <= input_sram_read_data;
        end
        STATE_READ_INPUT_4:
        begin
          current_state <= STATE_READ_INPUT_5;
          input_sram_read_address <= input_address + 5'd9;
          input_buffer[1] <= input_sram_read_data;
        end
        STATE_READ_INPUT_5:
        begin
          current_state <= STATE_READ_INPUT_6;
          input_sram_read_address <= input_address + 5'd16;
          input_buffer[2] <= input_sram_read_data;
        end
        STATE_READ_INPUT_6:
        begin
          current_state <= STATE_READ_INPUT_7;
          input_sram_read_address <= input_address + 5'd17;
          input_buffer[3] <= input_sram_read_data;
        end
        STATE_READ_INPUT_7:
        begin
          current_state <= STATE_READ_INPUT_8;
          input_buffer[4] <= input_sram_read_data;
        end
        STATE_READ_INPUT_8:
        begin
          // Last read of input data
          current_state <= STATE_READ_INPUT_9;
          input_buffer[5] <= input_sram_read_data;

          // Manage input address increment and row counting
          if (row_counter > 5)
          begin
            input_address <= input_address + 2'd2;
            row_counter <= 8'd0;
          end
          else
          begin
            input_address <= input_address + 1'b1;
            row_counter <= row_counter + 1'b1;
          end
        end

        //---------------------------------------------------------------------------
        // Compute output based on inputs and weights
        STATE_READ_INPUT_9:
        begin
          current_state <= STATE_COMPUTE_OUTPUT;

          // Apply ReLU activation to the computed outputs
          if (final_output > 127)
          begin
            relu_output[15:8] <= 8'd127;
          end
          else if (final_output < 0)
          begin
            relu_output[15:8] <= 8'd0;
          end
          else
          begin
            relu_output[15:8] <= final_output;
          end

          if (final_output2 > 127)
          begin
            relu_output[7:0] <= 8'd127;
          end
          else if (final_output2 < 0)
          begin
            relu_output[7:0] <= 8'd0;
          end
          else
          begin
            relu_output[7:0] <= final_output2;
          end
        end

        //---------------------------------------------------------------------------
        // Write computed output to Output SRAM
        STATE_COMPUTE_OUTPUT:
        begin
          output_sram_write_enable <= 1'b1;
          output_sram_write_addresss <= output_address;
          output_sram_write_data <= relu_output;  // Write ReLU output to SRAM
          output_address <= output_address + 1'b1;

          if (input_address > 110)
          begin
            // End of computation, move to writing final output
            current_state <= STATE_WRITE_OUTPUT;
          end
          else
          begin
            // Continue reading inputs for further computation
            current_state <= STATE_READ_INPUT_1;
          end
        end

        //---------------------------------------------------------------------------
        // Final State to Complete Output Writing
        STATE_WRITE_OUTPUT:
        begin
          current_state <= STATE_IDLE;
          output_sram_write_enable <= 1'b0;
          dut_busy <= 1'b0;  // Clear busy signal when done
        end

        //---------------------------------------------------------------------------
        // Default State: Return to Idle in case of unexpected behavior
        default:
        begin
          current_state <= STATE_IDLE;
        end
      endcase
    end
  end

  //---------------------------------------------------------------------------
  // Input Processing: Split input_buffer into processed 8-bit values
  assign processed_input[0] = input_buffer[0][15:8];
  assign processed_input[1] = input_buffer[0][7:0];
  assign processed_input[2] = input_buffer[1][15:8];

  assign processed_input[3] = input_buffer[2][15:8];
  assign processed_input[4] = input_buffer[2][7:0];
  assign processed_input[5] = input_buffer[3][15:8];

  assign processed_input[6] = input_buffer[4][15:8];
  assign processed_input[7] = input_buffer[4][7:0];
  assign processed_input[8] = input_buffer[5][15:8];

  assign processed_input[9] = input_buffer[0][7:0];
  assign processed_input[10] = input_buffer[1][15:8];
  assign processed_input[11] = input_buffer[1][7:0];

  assign processed_input[12] = input_buffer[2][7:0];
  assign processed_input[13] = input_buffer[3][15:8];
  assign processed_input[14] = input_buffer[3][7:0];

  assign processed_input[15] = input_buffer[4][7:0];
  assign processed_input[16] = input_buffer[5][15:8];
  assign processed_input[17] = input_buffer[5][7:0];


  //---------------------------------------------------------------------------
  // Weight Multiplication Results for First and Second Sets of Inputs
  assign multiplied_results[0] = processed_input[0]*weight_buffer[0];
  assign multiplied_results[1] = processed_input[1]*weight_buffer[1];
  assign multiplied_results[2] = processed_input[2]*weight_buffer[2];

  assign multiplied_results[3] = processed_input[3]*weight_buffer[3];
  assign multiplied_results[4] = processed_input[4]*weight_buffer[4];
  assign multiplied_results[5] = processed_input[5]*weight_buffer[5];

  assign multiplied_results[6] = processed_input[6]*weight_buffer[6];
  assign multiplied_results[7] = processed_input[7]*weight_buffer[7];
  assign multiplied_results[8] = processed_input[8]*weight_buffer[8];
  assign final_output = multiplied_results[0]+multiplied_results[1]+multiplied_results[2]+multiplied_results[3]+multiplied_results[4]+multiplied_results[5]+multiplied_results[6]+multiplied_results[7]+multiplied_results[8];

  assign multiplied_results2[0] = processed_input[9]*weight_buffer[0];
  assign multiplied_results2[1] = processed_input[10]*weight_buffer[1];
  assign multiplied_results2[2] = processed_input[11]*weight_buffer[2];

  assign multiplied_results2[3] = processed_input[12]*weight_buffer[3];
  assign multiplied_results2[4] = processed_input[13]*weight_buffer[4];
  assign multiplied_results2[5] = processed_input[14]*weight_buffer[5];

  assign multiplied_results2[6] = processed_input[15]*weight_buffer[6];
  assign multiplied_results2[7] = processed_input[16]*weight_buffer[7];
  assign multiplied_results2[8] = processed_input[17]*weight_buffer[8];
  assign final_output2 = multiplied_results2[0]+multiplied_results2[1]+multiplied_results2[2]+multiplied_results2[3]+multiplied_results2[4]+multiplied_results2[5]+multiplied_results2[6]+multiplied_results2[7]+multiplied_results2[8];


endmodule


