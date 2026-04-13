`include "defines.v"

module ipdc_test_v2 (
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

reg        out_valid;
reg [23:0] out_data;
reg [7:0]  pix_cnt;
reg [2:0]  state;
reg        display_en;

// latched inputs sampled on negedge
reg        op_valid_lat;
reg [3:0]  op_mode_lat;
reg        in_valid_lat;
reg [23:0] in_data_lat;

//Regs for input image and origin 
reg [23:0] img_reg [0:255];
reg [23:0] pix_center;

localparam IDLE    = 3'd0;
localparam LOADING = 3'd1;
localparam DISPLAY = 3'd2;
localparam READY_PULSE = 3'd3;
localparam WAIT_CMD = 3'd4;
localparam DONE_WAIT = 3'd5;
localparam CLEAN_WAIT = 3'd6;


wire get_data_wire;
wire [7:0] read_addr;
wire pix_valid;
wire display_done;

reg can_accept_op;

//Filter register 
reg [7:0] y_out, cb_out, cr_out;
reg signed [12:0] y_x8, cb_x8, cr_x8; 

reg [3:0] row_cur, col_cur; 
reg [7:0] med_r, med_g, med_b;
reg [7:0] cen_r, cen_g, cen_b; 

wire [2:0] sample_step_curr;


// ---------------------------------------------------------------------------
// Input sampler: sample external inputs on falling edge 
// ---------------------------------------------------------------------------

wire i_clk_n;
wire sample_cmd;

assign i_clk_n   = ~i_clk;
assign sample_cmd = i_op_valid && (state == WAIT_CMD);

always @(posedge i_clk_n or negedge i_rst_n) begin
    if (!i_rst_n) begin
        op_valid_lat <= 1'b0;
        op_mode_lat  <= 4'd0;
        in_valid_lat <= 1'b0;
        in_data_lat  <= 24'd0;
    end else begin
        op_valid_lat <= sample_cmd;
        if (sample_cmd)
            op_mode_lat <= i_op_mode;

        in_valid_lat <= i_in_valid;
        in_data_lat  <= i_in_data;
        
    end
end


// ---------------------------------------------------------------------------
// Submodules use latched command
// ---------------------------------------------------------------------------

reg [7:0] read_addr_r;
reg [2:0] sample_step_r;
reg [3:0] op_mode_r;
reg       pix_valid_r;


reg [3:0] row_r, col_r;

display_engine u_display_engine (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_op_valid(op_valid_lat),
    .i_op_mode(op_mode_lat),
    .i_display_en(display_en),
    .o_sample_step (sample_step_curr),
    .o_read_addr(read_addr),
    .o_pix_valid(pix_valid),
    .o_display_done(display_done)
);

always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        read_addr_r   <= 8'd0;
        sample_step_r <= 3'd1;
        op_mode_r     <= 4'd0;
        pix_valid_r   <= 1'b0;
        //r_center      <= 8'd0;
        //g_center      <= 8'd0;
        //b_center      <= 8'd0;
        pix_center <= 24'd0;
        row_r         <= 4'd0;
        col_r         <= 4'd0;
    end else begin
        pix_valid_r <= pix_valid;

        if (pix_valid) begin
            read_addr_r   <= read_addr;
            sample_step_r <= sample_step_curr;
            op_mode_r     <= op_mode_lat;
            row_r         <= read_addr[7:4];
            col_r         <= read_addr[3:0];
            /*r_center      <= R_reg[read_addr];
            g_center      <= G_reg[read_addr];
            b_center      <= B_reg[read_addr];*/
            pix_center <= img_reg[read_addr];
        end
    end
end

wire [7:0] r_center_w, g_center_w, b_center_w;

assign r_center_w = pix_center[23:16];
assign g_center_w = pix_center[15:8];
assign b_center_w = pix_center[7:0];
//Median filter helper functions 
//Zero pad out of bounds accesses 
function automatic [7:0] get_r;
	input integer row, col;
	integer addr; 
	begin 
		if (row < 0 || row > 15 || col < 0 || col > 15) 
			get_r = 8'd0;
		else begin 
			addr = row * 16 + col; 
			get_r = img_reg[addr][23:16];
		end 
	end 
endfunction

function automatic [7:0] get_g;
	input integer row, col;
	integer addr; 
	begin 
		if (row < 0 || row > 15 || col < 0 || col > 15) 
			get_g = 8'd0;
		else begin 
			addr = row * 16 + col; 
			get_g = img_reg[addr][15:8];
		end 
	end 
endfunction

function automatic [7:0] get_b;
	input integer row, col;
	integer addr; 
	begin 
		if (row < 0 || row > 15 || col < 0 || col > 15) 
			get_b = 8'd0;
		else begin 
			addr = row * 16 + col;
			get_b = img_reg[addr][7:0];
		end 
	end 
endfunction

/*function automatic [7:0] median9;
    input [7:0] a0,a1,a2,a3,a4,a5,a6,a7,a8;
    reg [7:0] arr [0:8];
    reg [7:0] tmp;
    integer i,j;
    begin
        arr[0]=a0; arr[1]=a1; arr[2]=a2;
        arr[3]=a3; arr[4]=a4; arr[5]=a5;
        arr[6]=a6; arr[7]=a7; arr[8]=a8;

        for (i=0; i<9; i=i+1) begin
            for (j=i+1; j<9; j=j+1) begin
                if (arr[j] < arr[i]) begin
                    tmp    = arr[i];
                    arr[i] = arr[j];
                    arr[j] = tmp;
                end
            end
        end

        median9 = arr[4];
    end
endfunction*/

function automatic [7:0] median9;
    input [7:0] a0,a1,a2,a3,a4,a5,a6,a7,a8;
    reg [7:0] b0,b1,b2,b3,b4,b5,b6,b7,b8;
    reg [7:0] t;
    begin
        b0=a0; b1=a1; b2=a2; b3=a3; b4=a4;
        b5=a5; b6=a6; b7=a7; b8=a8;

        // 27-comparator sorting network for 9 elements (verified)
        if(b0>b1) begin t=b0; b0=b1; b1=t; end
        if(b3>b4) begin t=b3; b3=b4; b4=t; end
        if(b6>b7) begin t=b6; b6=b7; b7=t; end
        if(b1>b2) begin t=b1; b1=b2; b2=t; end
        if(b4>b5) begin t=b4; b4=b5; b5=t; end
        if(b7>b8) begin t=b7; b7=b8; b8=t; end
        if(b0>b1) begin t=b0; b0=b1; b1=t; end
        if(b3>b4) begin t=b3; b3=b4; b4=t; end
        if(b6>b7) begin t=b6; b6=b7; b7=t; end
        if(b0>b3) begin t=b0; b0=b3; b3=t; end
        if(b3>b6) begin t=b3; b3=b6; b6=t; end
        if(b0>b3) begin t=b0; b0=b3; b3=t; end
        if(b1>b4) begin t=b1; b1=b4; b4=t; end
        if(b4>b7) begin t=b4; b4=b7; b7=t; end
        if(b1>b4) begin t=b1; b1=b4; b4=t; end
        if(b2>b5) begin t=b2; b2=b5; b5=t; end
        if(b5>b8) begin t=b5; b5=b8; b8=t; end
        if(b2>b5) begin t=b2; b2=b5; b5=t; end
        if(b1>b3) begin t=b1; b1=b3; b3=t; end
        if(b2>b4) begin t=b2; b2=b4; b4=t; end
        if(b2>b3) begin t=b2; b2=b3; b3=t; end
        if(b4>b6) begin t=b4; b4=b6; b6=t; end
        if(b5>b7) begin t=b5; b5=b7; b7=t; end
        if(b4>b5) begin t=b4; b4=b5; b5=t; end
        if(b3>b6) begin t=b3; b3=b6; b6=t; end
        if(b3>b4) begin t=b3; b3=b4; b4=t; end
        if(b5>b6) begin t=b5; b5=b6; b6=t; end

        median9 = b4;  // middle element after full sort
    end
endfunction
//Helper functions for Census Transform 
function automatic [7:0] census_r;
    input integer row, col, step;
    reg [7:0] c;
    begin
        c = get_r(row, col);
        census_r = {
            (get_r(row-step, col-step) > c), // top-left
            (get_r(row-step, col  ) > c), // top
            (get_r(row-step, col+step) > c), // top-right
            (get_r(row  , col-step) > c), // left
            (get_r(row  , col+step) > c), // right
            (get_r(row+step, col-step) > c), // bottom-left
            (get_r(row+step, col  ) > c), // bottom
            (get_r(row+step, col+step) > c)  // bottom-right
        };
    end
endfunction

function automatic [7:0] census_g;
    input integer row, col, step;
    reg [7:0] c;
    begin
        c = get_g(row, col);
        census_g = {
            (get_g(row-step, col-step) > c),
            (get_g(row-step, col  ) > c),
            (get_g(row-step, col+step) > c),
            (get_g(row  , col-step) > c),
            (get_g(row  , col+step) > c),
            (get_g(row+step, col-step) > c),
            (get_g(row+step, col  ) > c),
            (get_g(row+step, col+step) > c)
        };
    end
endfunction

function automatic [7:0] census_b;
    input integer row, col, step;
    reg [7:0] c;
    begin
        c = get_b(row, col);
        census_b = {
            (get_b(row-step, col-step) > c),
            (get_b(row-step, col  ) > c),
            (get_b(row-step, col+step) > c),
            (get_b(row  , col-step) > c),
            (get_b(row  , col+step) > c),
            (get_b(row+step, col-step) > c),
            (get_b(row+step, col  ) > c),
            (get_b(row+step, col+step) > c)
        };
    end
endfunction

//YCbCr Filter Calculations 
always @(*) begin
    y_x8   = 13'd0;
    cb_x8  = 13'd0;
    cr_x8  = 13'd0;
    y_out  = 8'd0;
    cb_out = 8'd0;
    cr_out = 8'd0;

    if (op_mode_r == `OP_YCBCR) begin
        y_x8  = (r_center_w << 1) + (g_center_w * 5);
				cb_x8 = -$signed({1'b0, r_center_w})
								- ($signed({1'b0, g_center_w}) << 1)
								+ ($signed({1'b0, b_center_w}) << 2)
								+ $signed(13'd1024);
				cr_x8 = ($signed({1'b0, r_center_w}) << 2)
								- ($signed({1'b0, g_center_w}) * 3)
								- $signed({1'b0, b_center_w})
								+ $signed(13'd1024);
								
				y_out  = (y_x8  + $signed(13'd4)) >>> 3;
        cb_out = (cb_x8 + $signed(13'd4)) >>> 3;
        cr_out = (cr_x8 + $signed(13'd4)) >>> 3;
    end
end

//Median Filter Calculations, with eff row and col extraction from 16x16 image 

always @(*) begin
    row_cur = row_r;
    col_cur = col_r;
    med_r   = 8'd0;
    med_g   = 8'd0;
    med_b   = 8'd0;

    if (op_mode_r == `OP_MEDIAN_FILTER) begin
        med_r = median9(
            get_r(row_cur-sample_step_r, col_cur-sample_step_r),
            get_r(row_cur-sample_step_r, col_cur),
            get_r(row_cur-sample_step_r, col_cur+sample_step_r),

            get_r(row_cur, col_cur-sample_step_r),
            get_r(row_cur, col_cur),
            get_r(row_cur, col_cur+sample_step_r),

            get_r(row_cur+sample_step_r, col_cur-sample_step_r),
            get_r(row_cur+sample_step_r, col_cur),
            get_r(row_cur+sample_step_r, col_cur+sample_step_r)
        );

        med_g = median9(
            get_g(row_cur-sample_step_r, col_cur-sample_step_r),
            get_g(row_cur-sample_step_r, col_cur),
            get_g(row_cur-sample_step_r, col_cur+sample_step_r),

            get_g(row_cur, col_cur-sample_step_r),
            get_g(row_cur, col_cur),
            get_g(row_cur, col_cur+sample_step_r),

            get_g(row_cur+sample_step_r, col_cur-sample_step_r),
            get_g(row_cur+sample_step_r, col_cur),
            get_g(row_cur+sample_step_r, col_cur+sample_step_r)
        );

        med_b = median9(
            get_b(row_cur-sample_step_r, col_cur-sample_step_r),
            get_b(row_cur-sample_step_r, col_cur),
            get_b(row_cur-sample_step_r, col_cur+sample_step_r),

            get_b(row_cur, col_cur-sample_step_r),
            get_b(row_cur, col_cur),
            get_b(row_cur, col_cur+sample_step_r),

            get_b(row_cur+sample_step_r, col_cur-sample_step_r),
            get_b(row_cur+sample_step_r, col_cur),
            get_b(row_cur+sample_step_r, col_cur+sample_step_r)
        );
    end
end

//Census Comb Block 
always @(*) begin
    cen_r = 8'd0;
    cen_g = 8'd0;
    cen_b = 8'd0;

    if (op_mode_r == `OP_CENSUS) begin
        cen_r = census_r(row_cur, col_cur, sample_step_r);
        cen_g = census_g(row_cur, col_cur, sample_step_r);
        cen_b = census_b(row_cur, col_cur, sample_step_r);
    end
end


//Pipeline RGB reg 
reg we_reg; 
reg [7:0] we_addr; 
reg [23:0] pix_wr;

always @ (posedge i_clk) begin 
	we_reg <= 1'b0;
	if (state == LOADING && in_valid_lat) begin 
		we_reg <= 1'b1;
		we_addr <= pix_cnt;
		pix_wr <= in_data_lat;
	end 
end 

always @ (posedge i_clk) begin 
	if (we_reg) begin 
		img_reg[we_addr] <= pix_wr;
	end 
end 
// ---------------------------------------------------------------------------
// Main FSM on rising edge
// ---------------------------------------------------------------------------
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        state      <= IDLE;
        //get_op     <= 1'b0;
        out_valid  <= 1'b0;
        out_data   <= 24'd0;
        pix_cnt    <= 8'd0;
        display_en <= 1'b0;
        //ready_pulsed <= 1'b0;
        can_accept_op <= 1'b0;
    end else begin
        out_valid  <= 1'b0;
        out_data   <= 24'd0;
        display_en <= 1'b0;
        //get_op     <= 1'b0;
        can_accept_op <= 1'b0;
		
        case (state)
            IDLE: begin
                 //get_op <= 1'b0;
                 
                 state <= READY_PULSE; 
            end
            
            READY_PULSE: begin 
            	//get_op <= 1'b1;
            	state <= WAIT_CMD;
            end 
            
            WAIT_CMD: begin 
            	can_accept_op <= 1'b1;
                if (op_valid_lat) begin 
                	if (op_mode_lat == `OP_LOAD) begin 
                		state <= LOADING; 
                		pix_cnt <= 8'd0;
                	end else begin 
                		state <= DISPLAY;
                	end 
                end
            end 

            LOADING: begin
            	//get_op <= 1'b0;
                if (in_valid_lat) begin               
                    if (pix_cnt == 8'd255) begin
                        pix_cnt <= 8'd0;
                        //get_op <= 1'b1;
                        state   <= READY_PULSE;
                    end else begin
                        pix_cnt <= pix_cnt + 8'd1;
                    end
                end
            end

            DISPLAY: begin
							display_en <= ~display_done;
                if (pix_valid_r) begin
										out_valid <= 1'b1;
										case (op_mode_r)
												`OP_YCBCR:         out_data <= {y_out, cb_out, cr_out};
												`OP_MEDIAN_FILTER: out_data <= {med_r, med_g, med_b};
												`OP_CENSUS:        out_data <= {cen_r, cen_g, cen_b};
												default:           out_data <= {r_center_w, g_center_w, b_center_w};
										endcase

								end

                if (display_done) begin
                    //get_op <= 1'b1;
                    state <= DONE_WAIT;
                end
            end
            
            DONE_WAIT: begin 
            	//One clean cycle with no out_valid or op_ready 
            	if (pix_valid_r) begin
										out_valid <= 1'b1;
										case (op_mode_r)
												`OP_YCBCR:         out_data <= {y_out, cb_out, cr_out};
												`OP_MEDIAN_FILTER: out_data <= {med_r, med_g, med_b};
												`OP_CENSUS:        out_data <= {cen_r, cen_g, cen_b};
												default:           out_data <= {r_center_w, g_center_w, b_center_w};
										endcase
										//out_data <= pix_center;
								end
            	state <= CLEAN_WAIT;
            end
            
            CLEAN_WAIT: begin 
            	state <= READY_PULSE;
            end 

            default: begin
                state <= READY_PULSE;
                //get_op <= 1'b0;
            end
        endcase
    end
end

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
assign o_op_ready  = (state == READY_PULSE);
assign o_in_ready  = (state == LOADING);
assign o_out_valid = out_valid;
assign o_out_data  = out_data;

endmodule
