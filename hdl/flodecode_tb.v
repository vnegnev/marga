//-----------------------------------------------------------------------------
// Title         : flodecode_tb
// Project       : ocra
//-----------------------------------------------------------------------------
// File          : flodecode_tb.v
// Author        :   <vlad@arch-ssd>
// Created       : 13.09.2020
// Last modified : 13.09.2020
//-----------------------------------------------------------------------------
// Description :
// 
// Testbench for flodecode, testing out the various features of the core
// 
//-----------------------------------------------------------------------------
// Copyright (c) 2020 by OCRA developers This model is the confidential and
// proprietary property of OCRA developers and the possession or use of this
// file requires a written license from OCRA developers.
//------------------------------------------------------------------------------
// Modification history :
// 13.09.2020 : created
//-----------------------------------------------------------------------------

`ifndef _FLODECODE_TB_
 `define _FLODECODE_TB_

 `include "flodecode.v"

 `timescale 1ns/1ns

module flodecode_tb;
   // Width of S_AXI data bus
   parameter integer C_S_AXI_DATA_WIDTH = 32;
   // Width of S_AXI address bus
   parameter integer C_S_AXI_ADDR_WIDTH = 19;

   parameter BUFS = 16;
   reg 		     err = 0;
		     
   /*AUTOREGINPUT*/
   // Beginning of automatic reg inputs (for undeclared instantiated-module inputs)
   reg			S_AXI_ACLK;		// To UUT of flodecode.v
   reg [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR;	// To UUT of flodecode.v
   reg			S_AXI_ARESETN;		// To UUT of flodecode.v
   reg [2:0]		S_AXI_ARPROT;		// To UUT of flodecode.v
   reg			S_AXI_ARVALID;		// To UUT of flodecode.v
   reg [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR;	// To UUT of flodecode.v
   reg [2:0]		S_AXI_AWPROT;		// To UUT of flodecode.v
   reg			S_AXI_AWVALID;		// To UUT of flodecode.v
   reg			S_AXI_BREADY;		// To UUT of flodecode.v
   reg			S_AXI_RREADY;		// To UUT of flodecode.v
   reg [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA;	// To UUT of flodecode.v
   reg [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB;// To UUT of flodecode.v
   reg			S_AXI_WVALID;		// To UUT of flodecode.v
   reg [31:0]		status_i;		// To UUT of flodecode.v
   reg [31:0]		status_latch_i;		// To UUT of flodecode.v
   reg			trig_i;			// To UUT of flodecode.v
   // End of automatics

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire			S_AXI_ARREADY;		// From UUT of flodecode.v
   wire			S_AXI_AWREADY;		// From UUT of flodecode.v
   wire [1:0]		S_AXI_BRESP;		// From UUT of flodecode.v
   wire			S_AXI_BVALID;		// From UUT of flodecode.v
   wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA;	// From UUT of flodecode.v
   wire [1:0]		S_AXI_RRESP;		// From UUT of flodecode.v
   wire			S_AXI_RVALID;		// From UUT of flodecode.v
   wire			S_AXI_WREADY;		// From UUT of flodecode.v
   wire [15:0]		data_o [BUFS-1:0];	// From UUT of flodecode.v
   wire [BUFS-1:0]	stb_o;			// From UUT of flodecode.v
   // End of automatics
   
   // Clock generation: assuming 100 MHz for convenience (in real design it'll be 122.88, 125 or 144 MHz depending on what's chosen)   
   always #5 S_AXI_ACLK = !S_AXI_ACLK;

   integer 		k;

   // Stimuli and read/write checks
   initial begin
      $dumpfile("icarus_compile/000_flodecode_tb.lxt");
      $dumpvars(0, flodecode_tb);

      S_AXI_ACLK = 1;
      S_AXI_ARADDR = 0;
      S_AXI_ARESETN = 0;
      S_AXI_ARPROT = 0;
      S_AXI_ARVALID = 0;
      S_AXI_AWADDR = 0;
      S_AXI_AWPROT = 0;
      S_AXI_AWVALID = 0;
      S_AXI_BREADY = 0;
      S_AXI_RREADY = 0;
      S_AXI_WDATA = 0;
      S_AXI_WSTRB = 0;
      S_AXI_WVALID = 0;

      trig_i = 0;
      status_i = 0;
      status_latch_i = 0;

      #107 S_AXI_ARESETN = 1; // extra 7ns to ensure that TB stimuli occur a bit before the positive clock edges
      S_AXI_BREADY = 1; // TODO: make this more fine-grained if bus reads/writes don't work properly in hardware

      // Test program 1: go idle
      #10 wr32(19'h40000, {1'b0, UUT.INSTR_FINISH, 24'd0});
      wr32(19'h0, 32'h1);
      // read back state, and make sure it's HALT, then stop the FSM
      #100 rd32(19'h10, {28'd2, {UUT.HALT}});
      wr32(19'h0, 32'h0);

      // Wait for 0 cycles then go idle
      wr32(19'h40000, {1'b0, UUT.INSTR_WAIT, 24'd0});
      wr32(19'h40004, {1'b0, UUT.INSTR_FINISH, 24'd0});
      // just toggle briefly; doesn't matter if no readout occurs
      wr32(19'h0, 32'h1);
      wr32(19'h0, 32'h0);
      
      // Wait for 10 cycles then go idle
      #50 wr32(19'h40000, {1'b0, UUT.INSTR_WAIT, 24'd10});
      wr32(19'h40004, {1'b0, UUT.INSTR_FINISH, 24'd0});
      wr32(19'h0, 32'h1);
      wr32(19'h0, 32'h0);
      
      // Wait for trigger with a timeout of 10 then go idle
      #150 wr32(19'h40000, {1'b0, UUT.INSTR_TRIG, 24'd10});
      wr32(19'h40004, {1'b0, UUT.INSTR_FINISH, 24'd0});
      wr32(19'h0, 32'h1);
      wr32(19'h0, 32'h0);

      // Wait for trigger as before, long delay, but have a trigger occur this time
      #150 wr32(19'h40000, {1'b0, UUT.INSTR_TRIG, 24'd20});
      wr32(19'h40004, {1'b0, UUT.INSTR_FINISH, 24'd0});
      wr32(19'h0, 32'h1);
      wr32(19'h0, 32'h0);
      #60 trig_i = !trig_i;

      // Wait for trigger as before, long delay, but have a trigger occur this time - only this time, no timeout
      #150 wr32(19'h40000, {1'b0, UUT.INSTR_TRIG_FOREVER, 24'd0});
      wr32(19'h40004, {1'b0, UUT.INSTR_FINISH, 24'd0});
      wr32(19'h0, 32'h1);
      #90 trig_i = !trig_i;      
      #40 wr32(19'h0, 32'h0);

      // Write 16 words with decreasing delay into buffers, so that they simultaneously appear at outputs
      #150 for (k = 0; k < BUFS; k = k + 1) wr32(19'h40000 + k*4, {1'b1, 7'(k), 8'(BUFS-k), 16'hdea0 + 16'(k)});
      wr32(19'h40000 + BUFS*4, {1'b0, UUT.INSTR_FINISH, 24'd0});
      wr32(19'h0, 32'h1);
      wr32(19'h0, 32'h0);

      // Write 64 words into buffers, so that they appear in a burst at the outputs
      #(30*BUFS) for (k = 0; k < BUFS; k = k + 1) wr32(19'h40000 + k*4, {1'b1, 7'(k), 8'(BUFS-k + 5*BUFS), 16'h1110 + 16'(k)});
      for (k = 0; k < BUFS; k = k + 1) wr32(19'h40040 + k*4, {1'b1, 7'(k), 8'd0, 16'h2220 + 16'(k)});
      for (k = 0; k < BUFS; k = k + 1) wr32(19'h40080 + k*4, {1'b1, 7'(k), 8'd0, 16'h3330 + 16'(k)});
      for (k = 0; k < BUFS; k = k + 1) wr32(19'h400c0 + k*4, {1'b1, 7'(k), 8'd0, 16'h4440 + 16'(k)});
      wr32(19'h40100, {1'b0, UUT.INSTR_FINISH, 24'd0});
      wr32(19'h0, 32'h1);
      wr32(19'h0, 32'h0);

      // TODO direct writes to buffers 
      #1100 wr32(19'hz, 1);
      
      // // BRAM writes, no delays
      // for (k = 0; k < 1000; k = k + 1) begin
      // 	 wr32(16'h8000 + (k << 2), k);
      // end

      // // BRAM writes, delays increasing from 0, 1 ... 7, down again
      // for (k = 8000; k < 8192; k = k + 1) begin
      // 	 wr32(16'h8000 + (k << 2), {2'd0, k[2:0], 3'd0, k[23:0]});
      // end

      // // Start outputting data; address 0
      // #100 data_enb_i = 1;

      // // Change output rate to be maximally fast (one output per 4 clock cycles), then change back to normal
      // #29300 wr32(16'd0, {16'd0, 16'd0});
      // #200 wr32(16'd0, {16'd0, 16'd303});

      // // Change BRAM offset (before previous output is finished)
      // #5000 offset_i = 10;
      // #5000 data_enb_i = 0;
      // #10 data_enb_i = 1;

      // // Simulate a 'busy' blip
      // #200 serial_busy_i = 1;
      // #10 serial_busy_i = 0;
      // #10 rd32(16'd16, {16'd0, 16'd11}); // no error bits

      // // Data error blip
      // #660 data_lost_i = 1;
      // #10 data_lost_i = 0;
      // #10 rd32(16'd16, {16'd1, 16'd11});

      // // Simulate a 'busy' condition that stays for a while, and a data lost error at the same time
      // #9000 serial_busy_i = 1; data_lost_i = 1;
      // #3000 serial_busy_i = 0; data_lost_i = 0;
      // #10 rd32(16'd16, {16'd3, 16'd15});

      // // Simulate a longer 'busy' condition that will compromise the output integrity
      // #10000 serial_busy_i = 1;
      // #10000 serial_busy_i = 0;
      // #10 rd32(16'd16, {16'd2, 16'd21});

      // // Reset core, make sure it resumes correctly
      // #500 S_AXI_ARESETN = 0;
      // #10 S_AXI_ARESETN = 1;

      // // TODO: reset behaviour in response to momentary reset isn't entirely clear.

      // // Change to the part of the memory with waits
      // #15000 S_AXI_ARESETN = 0;
      // offset_i = 8000;
      // data_enb_i = 0;
      // #10 S_AXI_ARESETN = 1;
      // #10 data_enb_i = 1;

      #200000 if (err) begin
	 $display("THERE WERE ERRORS");
	 $stop; // to return a nonzero error code if the testbench is later scripted at a higher level
      end
      $finish;
   end // initial begin

   // Output word checks at specific times
   integer n, p;
   wire [2:0] n_lsbs = n[2:0];
   initial begin
      // test timing/trigger instructions
      #185 check_state("PREPARE");
      #20 check_state("HALT");
      #150 check_state("HALT");
      #10 check_state("IDLE");

      #80 check_state("IDLE");
      #10 check_state("PREPARE");
      #50 check_state("HALT");
      #10 check_state("IDLE");

      #100 check_state("IDLE");
      #10 check_state("PREPARE");
      #120 check_state("COUNTDOWN");      
      #30 check_state("HALT");
      #10 check_state("IDLE");

      #100 check_state("IDLE");
      #10 check_state("PREPARE");
      #120 check_state("TRIG");      
      #30 check_state("HALT");
      #10 check_state("IDLE");

      #100 check_state("IDLE");
      #10 check_state("PREPARE");
      #120 check_state("TRIG");      
      #30 check_state("HALT");
      #10 check_state("IDLE");

      #160 check_state("IDLE");
      #10 check_state("PREPARE");
      #120 check_state("TRIG_FOREV");      
      #30 check_state("HALT");
      #10 check_state("IDLE");

      // test synchronised outputs via buffers
      #(40*BUFS + 260) for (k = 0; k < BUFS; k = k + 1) check_output(k, 16'hdea0 + k);

      #(30*BUFS + 2810) for (k = 0; k < BUFS; k = k + 1) check_output(k, 16'h1110 + k);
      #10 for (k = 0; k < BUFS; k = k + 1) check_output(k, 16'h2220 + k);
      #10 for (k = 0; k < BUFS; k = k + 1) check_output(k, 16'h3330 + k);
      #10 for (k = 0; k < BUFS; k = k + 1) check_output(k, 16'h4440 + k);
      
      // // test readout and speed logic
      // #225 check_output(32'habcd0123);
      
      // #36230 for (n = 0; n < 9; n = n + 1) begin
      // 	 check_output(n); #3070;
      // end
      // check_output(9); #1690; // speed up in the middle of pause
      // for (n = 10; n < 15; n = n + 1) begin
      // 	 check_output(n); #40;
      // end
      // check_output(15); #3070; // slow down in the middle of pause
      // for (n = 16; n < 18; n = n + 1) begin
      // 	 check_output(n); #3070;
      // end
      // check_output(18); #840;      

      // // test address reset and offset
      // for (n = 10; n < 13; n = n + 1) begin
      // 	 check_output(n); #3070;
      // end

      // // test busy causing a skipped valid output
      // check_output(13); 
      // #3070 if (valid_o == valid_mask) begin
      // 	 $display("%d ns: valid_o high, expected low due to serial_busy_i", $time);
      // 	 err <= 1;
      // end
      // #3070;
      // check_output(15); #3070 check_output(16); #3070;
      // check_output(17); #3070;
      // for (n = 0; n < 3; n = n + 1) begin
      // 	 if (valid_o == valid_mask) begin
      // 	    $display("%d ns: valid_o high, expected low due to serial_busy_i", $time);
      // 	    err <= 1;
      // 	 end
      // 	 #3070;
      // end
      // for (n = 21; n < 25; n = n + 1) begin
      // 	 check_output(n); #3070;
      // end
      // check_output(25); #2600; // uneven delay just from timing of the reconfiguration
      // // test larger intervals
      // for (n = 0; n < 16; n = n + 1) begin
      // 	 check_output({2'd0, n[2:0], 3'd0, 24'd8000 + n[23:0]});
      // 	 for (p = 0; p <= n[2:0]; p = p + 1) #3070;
      // end
   end // initial begin

   // Tasks for AXI bus reads and writes
   task wr32; //write to bus
      input [31:0] addr, data;
      begin
         #10 S_AXI_WDATA = data;
	 S_AXI_WSTRB = 'hf;
         S_AXI_AWADDR = addr;
         S_AXI_AWVALID = 1;
         S_AXI_WVALID = 1;
         fork
            begin: wait_axi_write
               wait(S_AXI_AWREADY && S_AXI_WREADY);
               disable axi_write_timeout;
            end
            begin: axi_write_timeout
               #10000 disable wait_axi_write;
	       $display("%d ns: AXI write timed out", $time);
            end
         join
         #13 S_AXI_AWVALID = 0;
         S_AXI_WVALID = 0;
      end
   endtask // wr32

   task rd32; //read from bus
      input [31:0] addr;
      input [31:0] expected;
      begin
         #10 S_AXI_ARVALID = 1;
         S_AXI_ARADDR = addr;
         wait(S_AXI_ARREADY);
         #13 S_AXI_ARVALID = 0;
         wait(S_AXI_RVALID);
         #13 if (expected !== S_AXI_RDATA) begin
            $display("%d ns: Bus read error, address %x, expected output %x, read %x.",
		     $time, addr, expected, S_AXI_RDATA);
            err <= 1'd1;
         end
         S_AXI_RREADY = 1;
         S_AXI_ARVALID = 0;
         #10 S_AXI_RREADY = 0;
      end
   endtask // rd32

   task check_output;
      input [$clog2(BUFS)-1:0] ch;
      input [15:0] data;
      begin
	 if (stb_o[ch] == 0) begin
	    $display("%d ns: stb_o[%d] low, expected high", $time, ch);
	    err <= 1;
	 end
	 if (data != data_o[ch]) begin
	    $display("%d ns: data_o[%d] expected 0x%x, saw 0x%x", $time, ch, data, data_o[ch]);
	    err <= 1;
	 end
      end
   endtask // check_output

   task check_state;
      input [79:0] expected;
      begin
	 if (state_ascii != expected) begin
	    $display("%d ns: state expected %s, saw %s", $time, expected, state_ascii);
	    err <= 1;
	 end
      end
   endtask
   
   flodecode #(/*AUTOINSTPARAM*/
	       // Parameters
	       .C_S_AXI_DATA_WIDTH	(C_S_AXI_DATA_WIDTH),
	       .C_S_AXI_ADDR_WIDTH	(C_S_AXI_ADDR_WIDTH),
	       .BUFS			(BUFS))
   UUT(/*AUTOINST*/
       // Outputs
       .data_o				(data_o/*[15:0].[BUFS-1:0]*/),
       .stb_o				(stb_o[BUFS-1:0]),
       .S_AXI_AWREADY			(S_AXI_AWREADY),
       .S_AXI_WREADY			(S_AXI_WREADY),
       .S_AXI_BRESP			(S_AXI_BRESP[1:0]),
       .S_AXI_BVALID			(S_AXI_BVALID),
       .S_AXI_ARREADY			(S_AXI_ARREADY),
       .S_AXI_RDATA			(S_AXI_RDATA[C_S_AXI_DATA_WIDTH-1:0]),
       .S_AXI_RRESP			(S_AXI_RRESP[1:0]),
       .S_AXI_RVALID			(S_AXI_RVALID),
       // Inputs
       .trig_i				(trig_i),
       .status_i			(status_i[31:0]),
       .status_latch_i			(status_latch_i[31:0]),
       .S_AXI_ACLK			(S_AXI_ACLK),
       .S_AXI_ARESETN			(S_AXI_ARESETN),
       .S_AXI_AWADDR			(S_AXI_AWADDR[C_S_AXI_ADDR_WIDTH-1:0]),
       .S_AXI_AWPROT			(S_AXI_AWPROT[2:0]),
       .S_AXI_AWVALID			(S_AXI_AWVALID),
       .S_AXI_WDATA			(S_AXI_WDATA[C_S_AXI_DATA_WIDTH-1:0]),
       .S_AXI_WSTRB			(S_AXI_WSTRB[(C_S_AXI_DATA_WIDTH/8)-1:0]),
       .S_AXI_WVALID			(S_AXI_WVALID),
       .S_AXI_BREADY			(S_AXI_BREADY),
       .S_AXI_ARADDR			(S_AXI_ARADDR[C_S_AXI_ADDR_WIDTH-1:0]),
       .S_AXI_ARPROT			(S_AXI_ARPROT[2:0]),
       .S_AXI_ARVALID			(S_AXI_ARVALID),
       .S_AXI_RREADY			(S_AXI_RREADY));

   // Wires purely for debugging (since GTKwave can't access a single RAM word directly)
   wire [31:0] bram_a0 = UUT.flo_bram[0], 
	       bram_a1 = UUT.flo_bram[1], 
	       bram_a1024 = UUT.flo_bram[1024], 
	       bram_a8000 = UUT.flo_bram[8000], 
	       bram_amax = UUT.flo_bram[65535];

   wire [15:0] data0_o = data_o[0], data1_o = data_o[1], data2_o = data_o[2], data3_o = data_o[3], 
	       data4_o = data_o[4], data5_o = data_o[5], data6_o = data_o[6], data7_o = data_o[7],
	       data8_o = data_o[8], data9_o = data_o[9], data10_o = data_o[10], data11_o = data_o[11],
	       data12_o = data_o[12], data13_o = data_o[13], data14_o = data_o[14], data15_o = data_o[15];

   
   // wire [23:0] data_o_lower = data_o[23:0]; // to avoid all 32 bits; just for visual debugging

   reg [79:0]  state_ascii = 0;
   always @(UUT.state) begin
      case (UUT.state)
	UUT.IDLE: state_ascii = "IDLE";
	UUT.PREPARE: state_ascii = "PREPARE";
	UUT.RUN: state_ascii = "RUN";
	UUT.COUNTDOWN: state_ascii = "COUNTDOWN";
	UUT.TRIG: state_ascii = "TRIG";
	UUT.TRIG_FOREVER: state_ascii = "TRIG_FOREV";
	UUT.HALT: state_ascii="HALT";
	default: state_ascii="UNKNOWN?";
      endcase // case (UUT.state)      
   end
endmodule // flodecode_tb
`endif //  `ifndef _FLODECODE_TB_

