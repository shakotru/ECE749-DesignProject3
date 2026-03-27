`include "defines.v"

module control_unit(
    input wire op_valid,
    input wire [3:0] op_mode,
    output reg get_data
);

always @* begin
	get_data = 0;
	if(op_valid) begin
		case (op_mode)
			`OP_LOAD:    begin
				get_data = 1;
			end
			`OP_SHIFT_RIGHT: begin
				get_data = 0;
			end
			`OP_SHIFT_LEFT: begin
				get_data = 0;
			end
			`OP_SHIFT_UP: begin
				get_data = 0;
			end
			`OP_SHIFT_DOWN: begin
				get_data = 0;
			end
			`OP_SCALE_DOWN: begin
				get_data = 0;
			end
			`OP_SCALE_UP: begin
				get_data = 0;
			end
			`OP_MEDIAN_FILTER: begin
				get_data = 0;
			end
			`OP_YCBCR: begin
				get_data = 0;
			end
			`OP_CENSUS: begin
				get_data = 0;
			end
			default: begin
				get_data = 0;
			end
		endcase
	end
end

always @(*) begin
    $display("CU: op_valid=%b op_mode=%b get_data=%b", op_valid, op_mode, get_data);
end

endmodule




