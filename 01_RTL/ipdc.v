
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
reg get_data;
reg out_valid;
reg [23:0] out_data;


// ---------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------
// ---- Add your own wire data assignments here if needed ---- //



// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------
// ---- Write your conbinational block design here ---- //



// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------
// ---- Write your sequential block design here ---- //
always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
        	get_data <= 0;
		out_valid <= 0;
		out_data <= 0;
	end else begin
		get_data <= 0;
                out_valid <= 0;
                out_data <= 0;
	end
end

assign o_in_ready = get_data;
assign o_out_valid = out_valid;
assign o_out_data = out_data;

endmodule
