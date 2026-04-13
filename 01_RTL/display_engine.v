`include "defines.v"

module display_engine (

input wire i_clk,
input wire i_rst_n,

input wire i_op_valid,
input wire [3:0] i_op_mode,

input wire i_display_en,
output wire [2:0] o_sample_step,

output reg [7:0] o_read_addr,
output reg o_pix_valid,
output reg o_display_done 
);

//internal regs for storing display and origin info
reg [3:0] ox, oy; //x and y dimensions of origin, which is the top left of the display window
reg [1:0] scale;

//REGS FOR BOUNDARY CHECK
reg [3:0] disp_col, disp_row;
reg [3:0] disp_max_r;
reg [2:0] sample_step_r;
reg [3:0] row_addr, col_addr;

assign o_sample_step = sample_step_r;

always @ (*) begin
	case (sample_step_r) 
		3'd1: begin 
			row_addr = oy + disp_row;
			col_addr = ox + disp_col;
		end 
		3'd2: begin
			row_addr = oy + {disp_row, 1'b0};
			col_addr = ox + {disp_col, 1'b0};
		end 
		default: begin 
			row_addr = oy + {disp_row, 2'b00};
			col_addr = ox + {disp_col, 2'b00};
		end 
	endcase
end 


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
		disp_max_r <= 4'd3;
		sample_step_r <= 3'd1;

       end else begin
	       o_pix_valid <= 0;
	       o_display_done <= 0;


	       if(i_op_valid) begin
   	           //$display("OP=%b ox=%d oy=%d scale=%d", i_op_mode, ox, oy, scale);
		       case(i_op_mode) 
			       `OP_SHIFT_RIGHT: if(ox+disp_max_r*sample_step_r+sample_step_r<15) ox <= ox+sample_step_r;
			       `OP_SHIFT_LEFT:  if((ox >= sample_step_r)) ox <= ox-sample_step_r;
		       	       `OP_SHIFT_UP:    if((oy >= sample_step_r)) oy <= oy-sample_step_r;
		       	       `OP_SHIFT_DOWN:  if((oy+disp_max_r*sample_step_r+sample_step_r)<=15) oy <= oy + sample_step_r;
		       	       
		       	       `OP_SCALE_DOWN: begin 
		       	       		if(scale > `SCALE_4) begin  
		       	       			scale <= scale-1;
		       	       			case (scale - 1) 
		       	       				`SCALE_16: begin 
		       	       					sample_step_r <= 3'd1;
		       	       					disp_max_r <= 4'd3;
		       	       				end 
		       	       				`SCALE_8: begin 
		       	       					sample_step_r <= 3'd2;
		       	       					disp_max_r <= 4'd1;
		       	       				end 
		       	       				default: begin 
		       	       					sample_step_r <= 3'd4;
		       	       					disp_max_r <= 4'd0;
		       	       				end 
		       	       			endcase
		       	       		end 
		       	       	end								
		       	       `OP_SCALE_UP: begin
		       	           if(scale < `SCALE_16) begin 
		       	           		scale <= scale+1;
		       	           		case (scale + 1'b1) 
		       	           			`SCALE_16: begin 
		       	           				sample_step_r <= 3'd1;
		       	           				disp_max_r <= 4'd3;
		       	           			end 
		       	           			`SCALE_8: begin 
		       	           				sample_step_r <= 3'd2;
		       	           				disp_max_r <= 4'd1;
		       	           			end 
		       	           			default: begin 
		       	           				sample_step_r <= 3'd4;
		       	           				disp_max_r <= 4'd0;
		       	           			end 
		       	           		endcase
		       	           	end 
		       	        end 
		       	       default: ;

		       endcase
		       disp_col <= 0;
		       disp_row <= 0;
	       end

	       //this is where we actually output things to display them :)
	       if (i_display_en) begin
		       //o_read_addr <= (oy + disp_row * sample_step) * 16 + (ox + disp_col * sample_step);
		       o_read_addr <= {row_addr, 4'd0} + col_addr;
		       o_pix_valid <= 1;


		       //reset everything to 0 once you finished display img
		       if(disp_col == disp_max_r) begin
			       	disp_col <= 0;
				if(disp_row == disp_max_r) begin
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
