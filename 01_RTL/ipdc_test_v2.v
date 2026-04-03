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

reg        get_op;
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
reg [7:0] R_lat;
reg [7:0] G_lat;
reg [7:0] B_lat;
reg [7:0] R_reg [0:255];
reg [7:0] G_reg [0:255];
reg [7:0] B_reg [0:255];

reg [23:0] img_storage [0:255];

localparam IDLE    = 3'd0;
localparam LOADING = 3'd1;
localparam DISPLAY = 3'd2;
localparam READY_PULSE = 3'd3;
localparam WAIT_CMD = 3'd4;
localparam DONE_WAIT = 3'd5;


wire get_data_wire;
wire [7:0] read_addr;
wire pix_valid;
wire display_done;

reg can_accept_op;

//Filter register 
reg [7:0] r_curr, g_curr, b_curr;
reg [7:0] y_out, cb_out, cr_out;
reg signed [12:0] y_x8, cb_x8, cr_x8; 

integer row_cur, col_cur; 
reg [7:0] med_r, med_g, med_b;
reg [7:0] cen_r, cen_g, cen_b; 

wire [2:0] sample_step_curr;


//reg op_pending; 
//reg [3:0] cmd_mode;

// ---------------------------------------------------------------------------
// Input sampler: sample external inputs on falling edge
// ---------------------------------------------------------------------------
always @(negedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        op_valid_lat <= 0;
        op_mode_lat  <= 0;
        in_valid_lat <= 0;
        in_data_lat  <= 0;
        R_lat <= 0;
        G_lat <= 0;
        B_lat <= 0;
    end else begin
       op_valid_lat <= 0;
        in_valid_lat <= i_in_valid;
        in_data_lat  <= i_in_data;
        R_lat <= i_in_data[23:16];
        G_lat <= i_in_data[15:8];
        B_lat <= i_in_data[7:0];
        
       
       if (i_op_valid && can_accept_op) begin 
            op_valid_lat <= 1;
            op_mode_lat <= i_op_mode;
        end else if (state != WAIT_CMD) begin 
        	op_valid_lat <= 0;
        end
    end
end

/*always @(posedge i_clk) begin
    $display("POS: state=%0d get_op=%b op_valid_lat=%b time=%0t", 
              state, get_op, op_valid_lat, $time);
end*/

// ---------------------------------------------------------------------------
// Submodules use latched command
// ---------------------------------------------------------------------------
control_unit u_control_unit (
    .op_valid(op_valid_lat),
    .op_mode(op_mode_lat),
    .get_data(get_data_wire)
);

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
			get_r = R_reg[addr];
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
			get_g = G_reg[addr];
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
			get_b = B_reg[addr];
		end 
	end 
endfunction

function automatic [7:0] median9;
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
always @ (*) begin 
	r_curr = R_reg[read_addr];
	g_curr = G_reg[read_addr];
	b_curr = B_reg[read_addr];
	
	y_x8 = (r_curr << 1) + (g_curr * 5);
	cb_x8 = -$signed({1'b0, r_curr}) - ($signed({1'b0, g_curr}) << 1) + ($signed({1'b0, b_curr}) << 2) + $signed(13'd1024);
	cr_x8 = ($signed({1'b0, r_curr}) << 2) - ($signed({1'b0, g_curr}) * 3) - $signed({1'b0, b_curr}) + $signed(13'd1024);
	
	y_out = (y_x8 + $signed(13'd4)) >>> 3; 
	cb_out = (cb_x8 + $signed(13'd4)) >>> 3;
	cr_out = (cr_x8 + $signed(13'd4)) >>> 3; 
end

//Median Filter Calculations, with eff row and col extraction from 16x16 image 
always @(*) begin
    row_cur = read_addr[7:4];
    col_cur = read_addr[3:0];

    med_r = median9(
        get_r(row_cur-sample_step_curr, col_cur-sample_step_curr),
        get_r(row_cur-sample_step_curr, col_cur),
        get_r(row_cur-sample_step_curr, col_cur+sample_step_curr),

        get_r(row_cur, col_cur-sample_step_curr),
        get_r(row_cur, col_cur),
        get_r(row_cur, col_cur+sample_step_curr),

        get_r(row_cur+sample_step_curr, col_cur-sample_step_curr),
        get_r(row_cur+sample_step_curr, col_cur),
        get_r(row_cur+sample_step_curr, col_cur+sample_step_curr)
    );

    med_g = median9(
        get_g(row_cur-sample_step_curr, col_cur-sample_step_curr),
        get_g(row_cur-sample_step_curr, col_cur),
        get_g(row_cur-sample_step_curr, col_cur+sample_step_curr),

        get_g(row_cur, col_cur-sample_step_curr),
        get_g(row_cur, col_cur),
        get_g(row_cur, col_cur+sample_step_curr),

        get_g(row_cur+sample_step_curr, col_cur-sample_step_curr),
        get_g(row_cur+sample_step_curr, col_cur),
        get_g(row_cur+sample_step_curr, col_cur+sample_step_curr)
    );

    med_b = median9(
        get_b(row_cur-sample_step_curr, col_cur-sample_step_curr),
        get_b(row_cur-sample_step_curr, col_cur),
        get_b(row_cur-sample_step_curr, col_cur+sample_step_curr),

        get_b(row_cur, col_cur-sample_step_curr),
        get_b(row_cur, col_cur),
        get_b(row_cur, col_cur+sample_step_curr),

        get_b(row_cur+sample_step_curr, col_cur-sample_step_curr),
        get_b(row_cur+sample_step_curr, col_cur),
        get_b(row_cur+sample_step_curr, col_cur+sample_step_curr)
    );
end

//Census Comb Block 
always @ (*) begin 
	cen_r = census_r (row_cur, col_cur, sample_step_curr);
	cen_g = census_g (row_cur, col_cur, sample_step_curr);
	cen_b = census_b (row_cur, col_cur, sample_step_curr);
end 

//o_op_ready pulse per spec 
reg ready_pulsed;
// ---------------------------------------------------------------------------
// Main FSM on rising edge
// ---------------------------------------------------------------------------
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        state      <= IDLE;
        get_op     <= 1'b0;
        out_valid  <= 1'b0;
        out_data   <= 24'd0;
        pix_cnt    <= 8'd0;
        display_en <= 1'b0;
        ready_pulsed <= 1'b0;
        can_accept_op <= 1'b0;

        //op_pending <= 1'b0;
        //cmd_mode <= 3'd0;
    end else begin
        out_valid  <= 1'b0;
        out_data   <= 24'd0;
        display_en <= 1'b0;
        get_op     <= 1'b0;
        can_accept_op <= 1'b0;

        
        /*if (op_valid_lat) begin 
        	op_pending <= 1;
        	cmd_mode <= op_mode_lat;
        end*/ 
        
        
		
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
                	//$display("READY: consuming op_mode=%b", op_mode_lat);
                	//get_op <= 1'b0;
                	//can_accept_op <= 1'b0;
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
                    img_storage[pix_cnt] <= in_data_lat;
                    R_reg[pix_cnt] <= R_lat;
                    G_reg[pix_cnt] <= G_lat;
                    B_reg[pix_cnt] <= B_lat;
                    
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
            	//get_op <= 1'b0;
                display_en <= 1'b1;

                if (pix_valid) begin
                    out_valid <= 1'b1;
                    case (op_mode_lat)
                    	`OP_YCBCR: out_data <= {y_out, cb_out, cr_out};
                    	`OP_MEDIAN_FILTER: out_data <= {med_r, med_g, med_b};
                    	`OP_CENSUS: out_data <= {cen_r, cen_g, cen_b};
                    	default: out_data  <= img_storage[read_addr];
                    endcase
                end

                if (display_done) begin
                    //get_op <= 1'b1;
                    state <= DONE_WAIT;
                end
            end
            
            DONE_WAIT: begin 
            	//One clean cycle with no out_valid or op_ready 
            	state <= READY_PULSE;
            end

            default: begin
                state <= READY_PULSE;
                get_op <= 1'b0;
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
