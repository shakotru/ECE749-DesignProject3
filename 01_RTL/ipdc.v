
module ipdc (                       //Don't modify interface
	input         i_clk,
	input         i_rst_n,
	input         i_op_valid,
	input  [ 3:0] i_op_mode,
    output        o_op_ready,
	input         i_in_valid,
	input  [23:0] i_in_data,
	output        o_in_ready,
	output        o_out_valid,
	output [23:0] o_out_data
);

// ---------------------------------------------------------------------------
// Wires and Registers
// ---------------------------------------------------------------------------
// ---- Add your own wires and registers here if needed ---- //
reg get_op;
reg out_valid;
reg [23:0] out_data;
reg op_valid;
reg [3:0] op_mode;
reg op_ready;
reg in_valid;
reg [23:0] in_data;

wire [3:0] op_mode_wire;
wire get_data_wire;
wire op_valid_wire;


initial begin 
	get_op = 1;
end

// --------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------
// ---- Add your own wire data assignments here if needed ---- //
//assign op_mode_wire = op_mode;
//assign get_data_wire = get_data;
//assign op_valid_wire = op_valid;

// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------
// ---- Write your conbinational block design here ---- //



control_unit u_control_unit(
	.get_data(get_data_wire),  //output
	.op_valid(i_op_valid),  //input
	.op_mode(i_op_mode)   //input
);


// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------
// ---- Write your sequential block design here ---- //
always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
		out_valid <= 0;
		out_data <= 0;
		get_op <= 0;
	end else begin
		//get_data <= 0;
                out_valid <= 0;
                out_data <= 0;
		get_op <= 1;
	end
end

assign op_mode_wire = op_mode;
assign op_valid_wire = op_valid;

assign o_op_ready = get_op;
assign o_in_ready = get_data_wire;
assign o_out_valid = out_valid;
assign o_out_data = out_data;

endmodule
