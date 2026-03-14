module control_unit(
    input wire op_valid,
    input wire [3:0] op_mode,
    output reg get_data
);

localparam [3:0] OP_LOAD 		= 4'b0000;
localparam [3:0] OP_SHIFT_RIGHT  	= 4'b0100;
localparam [3:0] OP_SHIFT_LEFT 		= 4'b0101;
localparam [3:0] OP_SHIFT_UP 		= 4'b0110;
localparam [3:0] OP_SHIFT_DOWN 		= 4'b0111;
localparam [3:0] OP_SCALE_DOWN 		= 4'b1000;
localparam [3:0] OP_SCALE_UP 		= 4'b1001;
localparam [3:0] OP_MEDIAN_FILTER 	= 4'b1100;
localparam [3:0] OP_YCBCR 		= 4'b1101;
localparam [3:0] OP_CENSUS 		= 4'b1110;

always @* begin
	get_data = 0;
	if(op_valid) begin
		case (op_mode)
			OP_LOAD:    begin
				get_data = 1;
			end
			OP_SHIFT_RIGHT: begin
				get_data = 0;
			end
			OP_SHIFT_LEFT: begin
				get_data = 0;
			end
			OP_SHIFT_UP: begin
				get_data = 0;
			end
			OP_SHIFT_DOWN: begin
				get_data = 0;
			end
			OP_SCALE_DOWN: begin
				get_data = 0;
			end
			OP_SCALE_UP: begin
				get_data = 0;
			end
			OP_MEDIAN_FILTER: begin
				get_data = 0;
			end
			OP_YCBCR: begin
				get_data = 0;
			end
			OP_CENSUS: begin
				get_data = 0;
			end
			default: begin
				get_data = 0;
			end
		endcase
	end
end

endmodule




