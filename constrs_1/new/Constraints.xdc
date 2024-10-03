# Clock Constraint
create_clock -name clk -period 5 [get_ports clk]
set_clock_uncertainty 0.05 [get_clocks clk]

# Input and Output Delays
set_input_delay 0.658 -clock [get_clocks clk] [all_inputs]
set_output_delay 0.566 -clock [get_clocks clk] [all_outputs]

# Load Constraint (optional if necessary)
set_load <calculated_load_value> [all_outputs]
