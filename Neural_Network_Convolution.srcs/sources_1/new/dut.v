`timescale 1ns / 1ps

module MyDesign (
    //---------------------------------------------------------------------------
    // Control signals
    //---------------------------------------------------------------------------
    input   wire dut_run,            // Signal to start the DUT (Design Under Test)
    output  reg dut_busy,            // Busy signal, high when DUT is processing
    input   wire reset_b,            // Active-low reset
    input   wire clk,                // Clock signal

    //---------------------------------------------------------------------------
    // Input SRAM interface
    //---------------------------------------------------------------------------
    output reg        input_sram_write_enable,    // Write enable signal for input SRAM
    output reg [11:0] input_sram_write_addresss,  // Write address for input SRAM
    output reg [15:0] input_sram_write_data,      // Write data for input SRAM
    output reg [11:0] input_sram_read_address,    // Read address for input SRAM
    input  wire [15:0] input_sram_read_data,      // Data read from input SRAM

    //---------------------------------------------------------------------------
    // Output SRAM interface
    //---------------------------------------------------------------------------
    output reg        output_sram_write_enable,    // Write enable signal for output SRAM
    output reg [11:0] output_sram_write_addresss,  // Write address for output SRAM
    output reg [15:0] output_sram_write_data,      // Data to be written to output SRAM
    output reg [11:0] output_sram_read_address,    // Read address for output SRAM
    input  wire [15:0] output_sram_read_data,      // Data read from output SRAM

    //---------------------------------------------------------------------------
    // Scratchpad SRAM interface
    //---------------------------------------------------------------------------
    output reg        scratchpad_sram_write_enable,    // Write enable signal for scratchpad SRAM
    output reg [11:0] scratchpad_sram_write_addresss,  // Write address for scratchpad SRAM
    output reg [15:0] scratchpad_sram_write_data,      // Write data for scratchpad SRAM
    output reg [11:0] scratchpad_sram_read_address,    // Read address for scratchpad SRAM
    input  wire [15:0] scratchpad_sram_read_data,      // Data read from scratchpad SRAM

    //---------------------------------------------------------------------------
    // Weights SRAM interface
    //---------------------------------------------------------------------------
    output reg        weights_sram_write_enable,    // Write enable signal for weights SRAM
    output reg [11:0] weights_sram_write_addresss,  // Write address for weights SRAM
    output reg [15:0] weights_sram_write_data,      // Write data for weights SRAM
    output reg [11:0] weights_sram_read_address,    // Read address for weights SRAM
    input  wire [15:0] weights_sram_read_data       // Data read from weights SRAM
  );

  //---------------------------------------------------------------------------
  // State machine parameters
  //---------------------------------------------------------------------------
  parameter Idle       = 4'b0000;  // Idle state
  parameter ReadWeight = 4'b0001;  // Reading weights from SRAM
  parameter SaveWeight = 4'b0010;  // Saving weights for convolution operation
  parameter ReadInput1 = 5'd3;     // State for reading first input for convolution
  parameter ReadInput2 = 5'd4;     // State for reading second input
  parameter ReadInput3 = 5'd5;     // Continue reading inputs for convolution
  parameter ReadInput4 = 5'd6;
  parameter ReadInput5 = 5'd7;
  parameter ReadInput6 = 5'd8;
  parameter ReadInput7 = 5'd9;
  parameter ReadInput8 = 5'd10;
  parameter ReadInput9 = 5'd11;
  parameter ReadInput10 = 5'd12;
  parameter ReadInput11 = 5'd13;

  reg [5:0] current_state = Idle;  // Current state of the state machine

  //---------------------------------------------------------------------------
  // Registers to store inputs and weights
  //---------------------------------------------------------------------------
  reg signed [15:0] inputs [5:0];     // Stores input data for convolution
  wire signed [7:0] tempinput[17:0];  // Temporary input data for convolution

  reg signed [7:0] weights [9:0];     // Stores weight data for convolution

  //---------------------------------------------------------------------------
  // Registers and wires for the convolution and ReLU operations
  //---------------------------------------------------------------------------
  wire signed [15:0] Multiplied [8:0];  // Stores results of input * weight multiplications
  wire signed [15:0] Multiplied2[8:0];  // Stores results for second output channel

  wire signed [19:0] outputs;    // Summed convolution output for first channel
  wire signed [19:0] outputs2;   // Summed convolution output for second channel

  reg signed [15:0] convrelu;    // Result after applying the ReLU function

  //---------------------------------------------------------------------------
  // Addresses and counters
  //---------------------------------------------------------------------------
  reg [11:0] inputsaddr, weightsaddr, outputsaddr; // Addresses for SRAM interfaces
  reg [10:0] nextrowcounter;  // Counter to track the next row for input reading

  //---------------------------------------------------------------------------
  // Main state machine
  //---------------------------------------------------------------------------
  always @(posedge clk)
  begin
    if (~reset_b)
    begin  // System reset, all control signals are cleared
      dut_busy <= 1'b0;
      weights_sram_write_enable <=1'b0;
      //weights_sram_write_addresss <=12'b0;
      //weights_sram_write_data <=16'b0;
      weights_sram_read_address <=12'b0;
      input_sram_write_enable <=1'b0;
      //input_sram_write_addresss <=12'b0;
      //input_sram_write_data <=16'b0;
      input_sram_read_address <=12'b0;
      output_sram_write_enable <=1'b0;
      output_sram_write_addresss <=12'b0;
      output_sram_write_data <=16'b0;
      //output_sram_read_address <=12'b0;
      inputsaddr <= 12'b0;
      weightsaddr <= 12'b0;
      outputsaddr <= 12'b0;
      nextrowcounter <= 10'd0;
    end
    else
    begin
      case(current_state)
        Idle:
        begin
          if (dut_run)
          begin
            current_state <= ReadWeight;  // Transition to read weights
            dut_busy <= 1'b1;  // Indicate DUT is busy
          end
          else
          begin
            current_state <= Idle;  // Remain in idle
            dut_busy <= 1'b0;
          end
        end

        ReadWeight:
        begin
          weights_sram_read_address <= weightsaddr;  // Read weight address
          weightsaddr <= weightsaddr + 1'b1;  // Increment address
          current_state <= SaveWeight;
        end

        SaveWeight:
        begin
          // Load weight data into weight registers
          {weights[(weights_sram_read_address*2)-2], weights[(weights_sram_read_address*2)-1]} <= weights_sram_read_data;

          if (weightsaddr > 5)  // Check if all weights are loaded
            current_state <= ReadInput1;  // Move to read input stage
          else
            current_state <= ReadWeight;
        end

        ReadInput1:
        begin
          input_sram_read_address <= inputsaddr;  // Read first input
          current_state <= ReadInput2;
        end

        ReadInput2:
        begin
          input_sram_read_address <= inputsaddr + 1'd1;  // Read second input
          current_state <= ReadInput3;
        end

        ReadInput3:
        begin
          inputs[0] <= input_sram_read_data;  // Store first input data
          input_sram_read_address <= inputsaddr + 8;  // Prepare to read next input
          current_state <= ReadInput4;
        end

        // Continue reading input data
        ReadInput4:
        begin
          inputs[1] <= input_sram_read_data;
          input_sram_read_address <= inputsaddr + 9;
          current_state <= ReadInput5;
        end
        ReadInput5:
        begin
          inputs[2] <= input_sram_read_data;
          input_sram_read_address <= inputsaddr + 16;
          current_state <= ReadInput6;
        end
        ReadInput6:
        begin
          inputs[3] <= input_sram_read_data;
          input_sram_read_address <= inputsaddr + 17;
          current_state <= ReadInput7;
        end
        ReadInput7:
        begin
          inputs[4] <= input_sram_read_data;
          current_state <= ReadInput8;
        end
        ReadInput8:
        begin
          inputs[5] <= input_sram_read_data;  // Store final input value
          if (nextrowcounter > 5)
          begin
            inputsaddr <= inputsaddr + 2;  // Move to next row
            nextrowcounter <= 0;
          end
          else
          begin
            inputsaddr <= inputsaddr + 1;  // Increment input address
            nextrowcounter <= nextrowcounter + 1;
          end
          current_state <= ReadInput9;
        end

        // Apply ReLU after convolution
        ReadInput9:
        begin
          // Apply ReLU function
          convrelu[15:8] <= (outputs > 127) ? 8'd127 : (outputs < 0) ? 8'd0 : outputs;
          convrelu[7:0]  <= (outputs2 > 127) ? 8'd127 : (outputs2 < 0) ? 8'd0 : outputs2;
          current_state <= ReadInput10;
        end

        ReadInput10:
        begin
          output_sram_write_enable <= 1'b1;  // Write convolved data to output SRAM
          output_sram_write_addresss <= outputsaddr;
          output_sram_write_data <= convrelu;
          outputsaddr <= outputsaddr + 1;

          if (inputsaddr > 110)  // End of convolution
            current_state <= ReadInput11;
          else
            current_state <= ReadInput1;  // Continue with next input
        end

        ReadInput11:
        begin
          dut_busy <= 1'b0;  // Done with processing
          current_state <= Idle;
          output_sram_write_enable <= 1'b0;
        end

        default:
          current_state <= Idle;
      endcase
    end
  end

  //---------------------------------------------------------------------------
  // Convolution operation and ReLU application
  //---------------------------------------------------------------------------

  // Extract input data for multiplication
  assign tempinput[0] = inputs[0][15:8];
  assign tempinput[1] = inputs[0][7:0];
  assign tempinput[2] = inputs[1][15:8];
  assign tempinput[3] = inputs[2][15:8];
  assign tempinput[4] = inputs[2][7:0];
  assign tempinput[5] = inputs[3][15:8];
  assign tempinput[6] = inputs[4][15:8];
  assign tempinput[7] = inputs[4][7:0];
  assign tempinput[8] = inputs[5][15:8];

  // Perform convolution (input * weight)
  assign Multiplied[0] = tempinput[0] * weights[0];
  assign Multiplied[1] = tempinput[1] * weights[1];
  assign Multiplied[2] = tempinput[2] * weights[2];
  assign Multiplied[3] = tempinput[3] * weights[3];
  assign Multiplied[4] = tempinput[4] * weights[4];
  assign Multiplied[5] = tempinput[5] * weights[5];
  assign Multiplied[6] = tempinput[6] * weights[6];
  assign Multiplied[7] = tempinput[7] * weights[7];
  assign Multiplied[8] = tempinput[8] * weights[8];

  // Sum the results to produce final output
  assign outputs = Multiplied[0] + Multiplied[1] + Multiplied[2] + Multiplied[3] + Multiplied[4] + Multiplied[5] + Multiplied[6] + Multiplied[7] + Multiplied[8];

  // Perform second channel convolution
  assign Multiplied2[0] = tempinput[9] * weights[0];
  assign Multiplied2[1] = tempinput[10] * weights[1];
  assign Multiplied2[2] = tempinput[11] * weights[2];
  assign Multiplied2[3] = tempinput[12] * weights[3];
  assign Multiplied2[4] = tempinput[13] * weights[4];
  assign Multiplied2[5] = tempinput[14] * weights[5];
  assign Multiplied2[6] = tempinput[15] * weights[6];
  assign Multiplied2[7] = tempinput[16] * weights[7];
  assign Multiplied2[8] = tempinput[17] * weights[8];

  // Sum the second channel results
  assign outputs2 = Multiplied2[0] + Multiplied2[1] + Multiplied2[2] + Multiplied2[3] + Multiplied2[4] + Multiplied2[5] + Multiplied2[6] + Multiplied2[7] + Multiplied2[8];

endmodule
