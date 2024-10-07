`timescale 1ns / 1ps
module MyDesign (
    //---------------------------------------------------------------------------
    //Control signals
    input   wire dut_run                    ,
    output  reg dut_busy                   ,
    input   wire reset_b                    ,
    input   wire clk                        ,

    //---------------------------------------------------------------------------
    //Input SRAM interface
    output reg        input_sram_write_enable    ,
    output reg [11:0] input_sram_write_addresss  ,
    output reg [15:0] input_sram_write_data      ,
    output reg [11:0] input_sram_read_address    ,
    input wire [15:0] input_sram_read_data       ,

    //---------------------------------------------------------------------------
    //Output SRAM interface
    output reg        output_sram_write_enable    ,
    output reg [11:0] output_sram_write_addresss  ,
    output reg [15:0] output_sram_write_data      ,
    output reg [11:0] output_sram_read_address    ,
    input wire [15:0] output_sram_read_data       ,

    //---------------------------------------------------------------------------
    //Scratchpad SRAM interface
    output reg        scratchpad_sram_write_enable    ,
    output reg [11:0] scratchpad_sram_write_addresss  ,
    output reg [15:0] scratchpad_sram_write_data      ,
    output reg [11:0] scratchpad_sram_read_address    ,
    input wire [15:0] scratchpad_sram_read_data       ,

    //---------------------------------------------------------------------------
    //Weights SRAM interface
    output reg        weights_sram_write_enable    ,
    output reg [11:0] weights_sram_write_addresss  ,
    output reg [15:0] weights_sram_write_data      ,
    output reg [11:0] weights_sram_read_address    ,
    input wire [15:0] weights_sram_read_data

  );

  parameter Idle=4'b0000;
  parameter ReadWeight=4'b0001;
  parameter SaveWeight=4'b0010;

  parameter ReadInput1= 5'd3;
  parameter ReadInput2= 5'd4;
  parameter ReadInput3= 5'd5;
  parameter ReadInput4= 5'd6;
  parameter ReadInput5= 5'd7;
  parameter ReadInput6= 5'd8;
  parameter ReadInput7= 5'd9;
  parameter ReadInput8= 5'd10;
  parameter ReadInput9= 5'd11;
  parameter ReadInput10= 5'd12;
  parameter ReadInput11= 5'd13;


  reg  [5:0] current_state = Idle; //state machine states

  reg signed [15:0] inputs [5:0];
  wire signed [7:0] tempinput[17:0];

  reg signed [7:0] weights [9:0];

  wire signed [15:0] Multiplied [8:0];
  wire signed [15:0] Multiplied2[8:0];

  wire signed [19:0] outputs;
  wire signed [19:0] outputs2;


  reg signed [15:0] convrelu;

  reg [11:0] inputsaddr, weightsaddr, outputsaddr; //addresses
  reg[10:0] nextrowcounter;


  always @(posedge clk)
  begin//state machine
    if (~reset_b)
    begin//system reset
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

          if(dut_run)
          begin
            current_state <= ReadWeight;

            weights_sram_write_enable <=1'b0;
            weights_sram_read_address <=12'b0;

            input_sram_write_enable <=1'b0;
            input_sram_read_address <=12'b0;

            output_sram_write_enable <=1'b0;
            output_sram_write_addresss <=12'b0;
            output_sram_write_data <=16'b0;

            inputsaddr <= 12'b0;
            weightsaddr <= 12'b0;
            outputsaddr <= 12'b0;

          end
          else
          begin
            current_state <= Idle;
            dut_busy <= 1'b0;

          end

        end
        ReadWeight:
        begin
          dut_busy <= 1'b1;
          current_state <= SaveWeight;
          weights_sram_write_enable <=1'b0;

          weights_sram_read_address <= weightsaddr;
          weightsaddr <= weightsaddr + 1'b1;

        end
        SaveWeight:
        begin

          if(weightsaddr>0)
          begin
            {weights[(weights_sram_read_address*2)-2'd2],weights[(weights_sram_read_address*2)-2'd1]} <= weights_sram_read_data; // put in if statement?
          end
          else
          begin
            weights[0] <= weights[0];
          end

          if(weightsaddr > 5)
          begin //if counter has reached the last address in the weights sram
            current_state <= ReadInput1;
          end
          else
          begin
            current_state <= ReadWeight;
          end

        end
        ReadInput1:
        begin
          current_state <= ReadInput2;
          output_sram_write_enable <=1'b0;
          input_sram_write_enable <=1'b0;
          input_sram_read_address <= inputsaddr;

        end
        ReadInput2:
        begin
          current_state <= ReadInput3;
          input_sram_read_address <= inputsaddr+1'd1;

        end
        ReadInput3:
        begin //here first value is recieved
          current_state <= ReadInput4;
          input_sram_read_address <= inputsaddr+5'd8;
          inputs[0]<= input_sram_read_data;


        end
        ReadInput4:
        begin
          current_state <= ReadInput5;
          input_sram_read_address <= inputsaddr+5'd9;
          inputs[1]<= input_sram_read_data;

        end
        ReadInput5:
        begin
          current_state <= ReadInput6;
          input_sram_read_address <= inputsaddr+5'd16;
          inputs[2]<= input_sram_read_data;

        end
        ReadInput6:
        begin
          current_state <= ReadInput7;
          input_sram_read_address <= inputsaddr+5'd17;
          inputs[3]<= input_sram_read_data;

        end
        ReadInput7:
        begin
          current_state <= ReadInput8;
          inputs[4]<= input_sram_read_data;

        end
        ReadInput8:
        begin //last of reads for conv arrives
          current_state <= ReadInput9;
          inputs[5]<= input_sram_read_data;

          if(nextrowcounter > 5)
          begin //if true move to next row
            inputsaddr <= inputsaddr + 2'd2;
            nextrowcounter <= 8'd0;
          end
          else
          begin
            inputsaddr <= inputsaddr + 1'b1;
            nextrowcounter <= nextrowcounter+1'b1;
          end
        end

        ReadInput9:
        begin
          current_state <= ReadInput10;

          if(outputs > 127)
          begin
            convrelu[15:8] <= 8'd127;
          end
          else if(outputs < 0)
          begin
            convrelu[15:8] <= 8'd0;
          end
          else
          begin
            convrelu[15:8] <= outputs;
          end

          if(outputs2 > 127)
          begin
            convrelu[7:0] <= 8'd127;
          end
          else if(outputs2 < 0)
          begin
            convrelu[7:0] <= 8'd0;
          end
          else
          begin
            convrelu[7:0] <= outputs2;
          end
          //convrelu[15:8] <= outputs;
          //convrelu[7:0] <= outputs2;


        end
        ReadInput10:
        begin

          //send
          output_sram_write_enable <=1'b1;
          output_sram_write_addresss <= outputsaddr;
          output_sram_write_data <= convrelu;//data  to write
          outputsaddr <= outputsaddr +1'b1;

          if(inputsaddr> 110)
          begin //if true end of convolution
            current_state <= ReadInput11;//add another state where done is aasserted then move to idle
          end
          else
          begin
            current_state <= ReadInput1;
          end

        end
        ReadInput11:
        begin
          current_state <= Idle;
          output_sram_write_enable <=1'b0;
          dut_busy <= 1'b0;

        end

        default:
        begin
          current_state <= Idle;
        end
      endcase
    end
  end

  assign tempinput[0] = inputs[0][15:8];
  assign tempinput[1] = inputs[0][7:0];
  assign tempinput[2] = inputs[1][15:8];

  assign tempinput[3] = inputs[2][15:8];
  assign tempinput[4] = inputs[2][7:0];
  assign tempinput[5] = inputs[3][15:8];

  assign tempinput[6] = inputs[4][15:8];
  assign tempinput[7] = inputs[4][7:0];
  assign tempinput[8] = inputs[5][15:8];

  assign tempinput[9] = inputs[0][7:0];
  assign tempinput[10] = inputs[1][15:8];
  assign tempinput[11] = inputs[1][7:0];

  assign tempinput[12] = inputs[2][7:0];
  assign tempinput[13] = inputs[3][15:8];
  assign tempinput[14] = inputs[3][7:0];

  assign tempinput[15] = inputs[4][7:0];
  assign tempinput[16] = inputs[5][15:8];
  assign tempinput[17] = inputs[5][7:0];



  assign Multiplied[0] = tempinput[0]*weights[0];
  assign Multiplied[1] = tempinput[1]*weights[1];
  assign Multiplied[2] = tempinput[2]*weights[2];

  assign Multiplied[3] = tempinput[3]*weights[3];
  assign Multiplied[4] = tempinput[4]*weights[4];
  assign Multiplied[5] = tempinput[5]*weights[5];

  assign Multiplied[6] = tempinput[6]*weights[6];
  assign Multiplied[7] = tempinput[7]*weights[7];
  assign Multiplied[8] = tempinput[8]*weights[8];
  assign outputs = Multiplied[0]+Multiplied[1]+Multiplied[2]+Multiplied[3]+Multiplied[4]+Multiplied[5]+Multiplied[6]+Multiplied[7]+Multiplied[8];

  assign Multiplied2[0] = tempinput[9]*weights[0];
  assign Multiplied2[1] = tempinput[10]*weights[1];
  assign Multiplied2[2] = tempinput[11]*weights[2];

  assign Multiplied2[3] = tempinput[12]*weights[3];
  assign Multiplied2[4] = tempinput[13]*weights[4];
  assign Multiplied2[5] = tempinput[14]*weights[5];

  assign Multiplied2[6] = tempinput[15]*weights[6];
  assign Multiplied2[7] = tempinput[16]*weights[7];
  assign Multiplied2[8] = tempinput[17]*weights[8];
  assign outputs2 = Multiplied2[0]+Multiplied2[1]+Multiplied2[2]+Multiplied2[3]+Multiplied2[4]+Multiplied2[5]+Multiplied2[6]+Multiplied2[7]+Multiplied2[8];


endmodule

