`include "defines.v"

module ipdc (
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
reg get_op;
reg out_valid;
reg [23:0] out_data;
reg [7:0] pix_cnt;
reg [2:0] state;
reg display_en;

// Input latches (sample on negedge per spec)
reg         op_valid_lat;
reg  [3:0]  op_mode_lat;
reg         in_valid_lat;
reg [23:0]  in_data_lat;
reg get_data_lat;

reg [23:0] img_storage [0:255];

localparam IDLE    = 3'd0;
localparam LOADING = 3'd1;
localparam READY   = 3'd2;
localparam DISPLAY = 3'd3;
localparam DONE = 3'd4;

// control_unit + display_engine wires
wire get_data_wire;
wire [7:0] read_addr;
wire pix_valid, display_done;

// ---------------------------------------------------------------------------
// Input Sampler (negedge per spec) --> REMOVE
always @(negedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        op_valid_lat <= 0;
        op_mode_lat  <= 0;
        in_valid_lat <= 0;
        in_data_lat  <= 0;
    end else begin
        op_valid_lat <= i_op_valid;
	if (i_op_valid && get_op)
        	op_mode_lat  <= i_op_mode;
        in_valid_lat <= i_in_valid;
        in_data_lat  <= i_in_data;
    end
end

// ---------------------------------------------------------------------------
// Submodules
// ---------------------------------------------------------------------------
control_unit u_control_unit (
    .get_data(get_data_wire),
    .op_valid(op_valid_lat),     // latched
    .op_mode(op_mode_lat)        // latched
);

display_engine u_display_engine (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_op_valid(op_valid_lat),   // latched
    .i_op_mode(op_mode_lat),     // latched
    .i_display_en(display_en),
    .o_read_addr(read_addr),
    .o_pix_valid(pix_valid),
    .o_display_done(display_done)
);

// Debug display
always @(posedge i_clk) begin
    //$display("t=%0t state=%0d op_valid_lat=%b op_mode_lat=%b get_data=%b",
      //        $time, state, op_valid_lat, op_mode_lat, get_data_wire);
end

// ---------------------------------------------------------------------------
// Main FSM (posedge)
always @(posedge i_clk or negedge i_rst_n) begin //keep posedge
    if (!i_rst_n) begin
        state      <= IDLE;
        out_valid  <= 0;
        out_data   <= 0;
        get_op     <= 0;
        pix_cnt    <= 0;
        display_en <= 0;
    end else begin
        out_valid  <= 0;
        out_data   <= 0;
        get_op     <= 0;
        display_en <= 0;
	//get_data_lat <= get_data_wire;  // Register it







        case (state)
            IDLE: begin
                //get_op <= 1;
                if (op_valid_lat) begin
		    get_op <= 0; //we only want get_op when the previous op's output is finished displaying
                    if (get_data_wire) begin
                        state   <= LOADING;
                        pix_cnt <= 0;
                        get_op  <= 0;
                    end else begin
                        state <= DISPLAY;
                    end
                end else begin
			get_op <= 1;  //only when op is not valid
		end
            end

            LOADING: begin
                if (in_valid_lat) begin
                    img_storage[pix_cnt] <= in_data_lat;
                    if (pix_cnt == 255) begin
                        pix_cnt <= 0;
                        state   <= READY;
                    end else begin
                        pix_cnt <= pix_cnt + 1;
                    end
                end
            end

            READY: begin
                //get_op <= 1;
                state  <= IDLE;
            end

            DISPLAY: begin
                display_en <= 1;
                if (pix_valid) begin
                    out_valid <= 1;
                    out_data  <= img_storage[read_addr];
                end
                if (display_done) begin
                    display_en <= 0;
                    //get_op     <= 1;
                    state      <= DONE;
                end
            end
	    DONE: begin 
		state <= IDLE; //just a delay so the last pixel has a chance to display itself

	    end
        endcase
    end
end

always @(posedge i_clk) begin
    $display("t=%0t | state=%0d | get_op=%b | op_valid_lat=%b | op_mode_lat=%b | in_valid_lat=%b | pix_cnt=%0d | display_en=%b | pix_valid=%b | display_done=%b | out_valid=%b | out_data=%h",
        $time, state, get_op, op_valid_lat, op_mode_lat, in_valid_lat, pix_cnt, display_en, pix_valid, display_done, out_valid, out_data);
end



// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
assign o_op_ready  = get_op;
assign o_in_ready  = (state == LOADING);
assign o_out_valid = out_valid;
assign o_out_data  = out_data;

endmodule

