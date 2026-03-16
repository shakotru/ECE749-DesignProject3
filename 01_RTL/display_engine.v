`include "defines.v"

module display_engine (

//inputs: op_valid, op_mode, clk, rst_n
//outputs: ox, oy, display_size

input wire i_clk,
input wire i_rst_n,

input wire i_op_valid,
input wire [3:0] i_op_mode,

input wire i_display_en,

output reg [7:0] o_read_addr,
output reg o_pix_valid,
output reg o_display_done 
);

//internal regs for storing display and origin info
reg [3:0] ox, oy; //x and y dimensions of origin, which is the top left of the display window
reg [1:0] scale;

//REGS FOR BOUNDARY CHECK
reg [3:0] disp_col, disp_row;
wire [3:0] disp_max; //highest index in the display window, not strictly needed but will be helpful for boundary check
assign disp_max = (scale == `SCALE_4) ? 4'd3 : (scale == `SCALE_8) ? 4'd7 : 4'd15;


always @(posedge i_clk or negedge i_rst_n) begin
       if(!i_rst_n) begin
		o_read_addr <= 0;
		o_pix_valid <= 0;
		o_display_done <= 0;
		ox <= 0;
		oy <= 0;
		scale <= `SCALE_16;
		disp_col <= 0;
		disp_row <= 0;

       end else begin
	       o_pix_valid <= 0;
	       o_display_done <= 0;


	       if(i_op_valid) begin
		       case(i_op_mode) 
			       `OP_SHIFT_RIGHT: if(ox+disp_max<15) ox <= ox+1;
			       `OP_SHIFT_LEFT:  if((ox > 0)) ox <= ox-1;
		       	       `OP_SHIFT_UP:    if((oy > 0)) oy <= oy-1;
		       	       `OP_SHIFT_DOWN:  if((oy+disp_max)<15) oy <= oy + 1;
		       	       `OP_SCALE_DOWN:  if(scale > `SCALE_4) scale <= scale-1;
		       	       `OP_SCALE_UP:    if(scale < `SCALE_16) scale <= scale+1;
		       	       default: ;

		       endcase
		       disp_col <= 0;
		       disp_row <= 0;
	       end

	       //this is where we actually output things to display them :)
	       if (i_display_en) begin
		       o_read_addr <= (oy + disp_row) * 16 + (ox + disp_col);
		       o_pix_valid <= 1;


		       //reset everything to 0 once you finished display img
		       if(disp_col == disp_max) begin
			       	disp_col <= 0;
				if(disp_row == disp_max) begin
					disp_row <= 0;
					o_display_done <= 1;
				end else begin
					disp_row <= disp_row + 1;
				end
			end else begin
				disp_col <= disp_col + 1;
			end

	       end


       end
end


endmodule
