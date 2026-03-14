`timescale 1ns/100ps
`define CYCLE       10.0     // CLK period.
`define HCYCLE      (`CYCLE/2)
`define MAX_CYCLE   10000000
`define RST_DELAY   2


`ifdef tb1
    `define INFILE "../00_TESTBED/PATTERN/indata1.dat"
    `define OPFILE "../00_TESTBED/PATTERN/opmode1.dat"
    `define GOLDEN "../00_TESTBED/PATTERN/golden1.dat"
`elsif tb2
    `define INFILE "../00_TESTBED/PATTERN/indata2.dat"
    `define OPFILE "../00_TESTBED/PATTERN/opmode2.dat"
    `define GOLDEN "../00_TESTBED/PATTERN/golden2.dat"
`elsif tb3
    `define INFILE "../00_TESTBED/PATTERN/indata3.dat"
    `define OPFILE "../00_TESTBED/PATTERN/opmode3.dat"
    `define GOLDEN "../00_TESTBED/PATTERN/golden3.dat"
`else
    `define INFILE "../00_TESTBED/PATTERN/indata0.dat"
    `define OPFILE "../00_TESTBED/PATTERN/opmode0.dat"
    `define GOLDEN "../00_TESTBED/PATTERN/golden0.dat"
    `define DATA_NUM 21
`endif

`define SDFFILE "ipdc_syn.sdf"  // Modify your sdf file name


module testbed;

reg clk, rst_n;
wire        op_valid;
wire [ 3:0] op_mode;
wire        op_ready;
wire        in_valid;
wire [23:0] in_data;
wire        in_ready;
wire        out_valid;
wire [23:0] out_data;

reg [23:0] indata_mem [ 0:255];
reg [ 3:0] opmode_mem [ 0:63];
reg [23:0] golden_mem [ 0:1024];

integer i;

// ==============================================
// TODO: Declare regs and wires you need
// ==============================================


// For gate-level simulation only
`ifdef SDF
    initial $sdf_annotate(`SDFFILE, u_ipdc);
    initial #1 $display("SDF File %s were used for this simulation.", `SDFFILE);
`endif

// Write out waveform file
initial begin
  $dumpfile("ipdc.vcd");
  $dumpvars( );
end


ipdc u_ipdc (
	.i_clk(clk),
	.i_rst_n(rst_n),
	.i_op_valid(op_valid),
	.i_op_mode(op_mode),
        .o_op_ready(op_ready),
	.i_in_valid(in_valid),
	.i_in_data(in_data),
	.o_in_ready(in_ready),
	.o_out_valid(out_valid),
	.o_out_data(out_data)
);

// Read in test pattern and golden pattern
initial $readmemb(`INFILE, indata_mem);
initial $readmemb(`OPFILE, opmode_mem);
initial $readmemb(`GOLDEN, golden_mem);

// Clock generation
initial clk = 1'b0;
always begin #(`CYCLE/2) clk = ~clk; end

// Reset generation
initial begin
    rst_n = 1; # (               0.25 * `CYCLE);
    rst_n = 0; # ((`RST_DELAY - 0.25) * `CYCLE);
    rst_n = 1; # (         `MAX_CYCLE * `CYCLE);
    $display("Error! Runtime exceeded!");
    $finish;
end

// ==============================================
// TODO: Check pattern after process finish
// ==============================================

// Stage 1: Drive wires with regs
reg tb_op_valid, tb_in_valid;
reg [3:0] tb_op_mode;
reg [7:0] img_cnt;    // 0..255 pixels
reg [5:0] op_cnt;     // 0..63 ops
reg [10:0] out_cnt;   // Output checker
integer mismatch_cnt;


assign op_valid = tb_op_valid;
assign op_mode  = tb_op_mode;
assign in_valid = tb_in_valid;
assign in_data  = indata_mem[img_cnt];



initial begin 
	clk = 0;
	rst_n = 1;
	i = 0;
	tb_op_valid = 0;
	tb_in_valid = 0; 
	tb_op_mode = 0;
	img_cnt = 0;
	op_cnt = 0;
	out_cnt = 0;
	mismatch_cnt = 0;

	@(negedge rst_n);
	@(posedge clk);
	$display("TESTBENCH START");

	while (op_cnt < `DATA_NUM) begin 
		wait (op_ready ==1);
		@(negedge clk);
		tb_op_valid = 1;
		tb_op_mode = opmode_mem[op_cnt];
		op_cnt = op_cnt + 1;
		$display("operation number [%0d]  = %b", op_cnt-1,  tb_op_mode);			
		@(posedge clk);
		tb_op_valid = 0;
	end

$display("all opcodes sent!!!");

end


//	while (i<`DATA_NUM) begin
//		@(negedge clk);
//		op_valid = $random;
//		if (op_valid) begin
//			op_mode = opmode_mem[i];
//		end
//
//	end


endmodule
