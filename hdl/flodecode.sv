//-----------------------------------------------------------------------------
// Title         : flodecode
// Project       : flocra
//-----------------------------------------------------------------------------
// File          : flodecode.sv
// Author        :   <vlad@arch-ssd>
// Created       : 17.12.2020
// Last modified : 17.12.2020
//-----------------------------------------------------------------------------
// Description :
//
// Stores main BRAM, output FSM, timer, RX FIFOs, parameterised output
// buses, and status registers (which receive signals from
// outside). Does NOT handle the exact connections and status register
// inputs - these must be handled at a higher level.
//
//-----------------------------------------------------------------------------
// Copyright (c) 2020 by OCRA developers This model is the confidential and
// proprietary property of OCRA developers and the possession or use of this
// file requires a written license from OCRA developers.
//------------------------------------------------------------------------------

`ifndef _FLODECODE_
 `define _FLODECODE_

 `include "flobuffer.sv"
 `include "flofifo.sv"

 `timescale 1ns / 1ns

module flodecode #
  (
   parameter integer C_S_AXI_DATA_WIDTH = 32,
   parameter integer C_S_AXI_ADDR_WIDTH = 19,   
   parameter BUFS = 24, // max 128; probably needs pipelining with that many
   parameter RX_FIFO_LENGTH = 16384 // must be power of 2
   )
   (
    // // Users to add ports here
    input 				 trig_i,
    input [31:0] 			 status_i, // un-latched inputs; read whatever is there
    input [31:0] 			 status_latch_i, // latched inputs; single-cycle high events are saved until read occurs

    output [15:0] 			 data_o[BUFS-1:0],
    output [BUFS-1:0] 			 stb_o,

    // stream interface, FIFOs
    input [63:0] 			 rx0_data,
    input 				 rx0_valid,
    output 				 rx0_ready,

    input [63:0] 			 rx1_data,
    input 				 rx1_valid,
    output 				 rx1_ready,

    // User ports end
    // Ports beyond this line were auto-generated by Xilinx

    // Global Clock Signal
    input 				 S_AXI_ACLK,
    // Global Reset Signal. This Signal is Active LOW
    input 				 S_AXI_ARESETN,
    // Write address (issued by master, acceped by Slave)
    input [C_S_AXI_ADDR_WIDTH-1 : 0] 	 S_AXI_AWADDR,
    // Write channel Protection type. This signal indicates the
    // privilege and security level of the transaction, and whether
    // the transaction is a data access or an instruction access.
    input [2 : 0] 			 S_AXI_AWPROT,
    // Write address valid. This signal indicates that the master signaling
    // valid write address and control information.
    input 				 S_AXI_AWVALID,
    // Write address ready. This signal indicates that the slave is ready
    // to accept an address and associated control signals.
    output 				 S_AXI_AWREADY,
    // Write data (issued by master, acceped by Slave) 
    input [C_S_AXI_DATA_WIDTH-1 : 0] 	 S_AXI_WDATA,
    // Write strobes. This signal indicates which byte lanes hold
    // valid data. There is one write strobe bit for each eight
    // bits of the write data bus.    
    input [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    // Write valid. This signal indicates that valid write
    // data and strobes are available.
    input 				 S_AXI_WVALID,
    // Write ready. This signal indicates that the slave
    // can accept the write data.
    output 				 S_AXI_WREADY,
    // Write response. This signal indicates the status
    // of the write transaction.
    output [1 : 0] 			 S_AXI_BRESP,
    // Write response valid. This signal indicates that the channel
    // is signaling a valid write response.
    output 				 S_AXI_BVALID,
    // Response ready. This signal indicates that the master
    // can accept a write response.
    input 				 S_AXI_BREADY,
    // Read address (issued by master, acceped by Slave)
    input [C_S_AXI_ADDR_WIDTH-1 : 0] 	 S_AXI_ARADDR,
    // Protection type. This signal indicates the privilege
    // and security level of the transaction, and whether the
    // transaction is a data access or an instruction access.
    input [2 : 0] 			 S_AXI_ARPROT,
    // Read address valid. This signal indicates that the channel
    // is signaling valid read address and control information.
    input 				 S_AXI_ARVALID,
    // Read address ready. This signal indicates that the slave is
    // ready to accept an address and associated control signals.
    output 				 S_AXI_ARREADY,
    // Read data (issued by slave)
    output [C_S_AXI_DATA_WIDTH-1 : 0] 	 S_AXI_RDATA,
    // Read response. This signal indicates the status of the
    // read transfer.
    output [1 : 0] 			 S_AXI_RRESP,
    // Read valid. This signal indicates that the channel is
    // signaling the required read data.
    output 				 S_AXI_RVALID,
    // Read ready. This signal indicates that the master can
    // accept the read data and response information.
    input 				 S_AXI_RREADY
    );

   // Instruction set
   localparam INSTR_FINISH = 7'h1, INSTR_WAIT = 7'h2, INSTR_TRIG = 7'h3, INSTR_TRIG_FOREVER = 7'h4;

   // AXI4LITE signals
   reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	      axi_awaddr;
   reg 					      axi_awready;
   reg 					      axi_wready;
   reg [1 : 0] 				      axi_bresp;
   reg 					      axi_bvalid;
   reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	      axi_araddr;
   reg 					      axi_arready;
   reg [C_S_AXI_DATA_WIDTH-1 : 0] 	      axi_rdata;
   reg [1 : 0] 				      axi_rresp;
   reg 					      axi_rvalid;

   wire 				      clk = S_AXI_ACLK, rstn = S_AXI_ARESETN;

   // Example-specific design signals
   // local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
   // ADDR_LSB is used for addressing 32/64 bit registers/memories
   // ADDR_LSB = 2 for 32 bits (n downto 2)
   // ADDR_LSB = 3 for 64 bits (n downto 3)
   localparam integer 			      ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;

   // flodecode default: 19 - 2 - 1 = 16   
   localparam integer 			      OPT_MEM_ADDR_BITS = C_S_AXI_ADDR_WIDTH - ADDR_LSB - 1; 
   //----------------------------------------------
   //-- Signals for user logic register space example
   //------------------------------------------------
   //-- Number of Slave Registers: 16
   reg [C_S_AXI_DATA_WIDTH-1:0] 	      slv_reg0 = {32'd0}; // R/W: bit 0 = run/stop, bit 1 = immediate stop, 
   wire 				      run_fsm = slv_reg0[0], stop_fsm = slv_reg0[1];
   reg [C_S_AXI_DATA_WIDTH-1:0] 	      slv_reg1 = {32'd0}; // R/W, 
   reg [C_S_AXI_DATA_WIDTH-1:0] 	      slv_reg2 = {32'd0}; // R/W, direct output control
   wire [6:0] 				      direct_valid = slv_reg2[22:16]; // output buffer for immediate transfers
   wire [15:0] 				      direct_data = slv_reg2[15:0];
   reg [C_S_AXI_DATA_WIDTH-1:0] 	      slv_reg3 = 0; // R/W

   reg [C_S_AXI_DATA_WIDTH-1:0] 	      slv_reg4 = 0; // read-only
   reg [C_S_AXI_DATA_WIDTH-1:0] 	      slv_reg5 = 0;
   
   reg [C_S_AXI_DATA_WIDTH-1:0] 	      slv_reg6 = 0; // read-only
   reg [C_S_AXI_DATA_WIDTH-1:0] 	      slv_reg7 = 0;  // read-only
   reg [C_S_AXI_DATA_WIDTH-1:0] 	      slv_reg8 = 0;  // read-only
   reg [C_S_AXI_DATA_WIDTH-1:0] 	      slv_reg9 = 0;  // read-only
   reg [C_S_AXI_DATA_WIDTH-1:0] 	      slv_reg10 = 0;  // read-only
   reg [C_S_AXI_DATA_WIDTH-1:0] 	      slv_reg11 = 0;  // read-only
   reg [C_S_AXI_DATA_WIDTH-1:0] 	      slv_reg12 = 0;  // read-only
   reg [C_S_AXI_DATA_WIDTH-1:0] 	      slv_reg13 = 0;  // read-only
   reg [C_S_AXI_DATA_WIDTH-1:0] 	      slv_reg14 = 0;  // read-only
   reg [C_S_AXI_DATA_WIDTH-1:0] 	      slv_reg15 = 0;  // read-only   
   
   wire 				      slv_reg_rden;
   wire 				      slv_reg_wen;
   reg [C_S_AXI_DATA_WIDTH-1:0] 	      reg_data_out = 0;
   integer 				      byte_index;
   reg 					      aw_en = 0;

   // I/O Connections assignments

   assign S_AXI_AWREADY	= axi_awready;
   assign S_AXI_WREADY	= axi_wready;
   assign S_AXI_BRESP	= axi_bresp;
   assign S_AXI_BVALID	= axi_bvalid;
   assign S_AXI_ARREADY	= axi_arready;
   assign S_AXI_RDATA	= axi_rdata;
   assign S_AXI_RRESP	= axi_rresp;
   assign S_AXI_RVALID	= axi_rvalid;
   // Implement axi_awready generation
   // axi_awready is asserted for one S_AXI_ACLK clock cycle when both
   // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
   // de-asserted when reset is low.

   always @( posedge clk ) begin
      if ( !rstn ) begin
	 axi_awready <= 1'b0;
	 aw_en <= 1'b1;
      end else begin    
	 if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
	    // slave is ready to accept write address when 
	    // there is a valid write address and write data
	    // on the write address and data bus. This design 
	    // expects no outstanding transactions. 
	    axi_awready <= 1'b1;
	    aw_en <= 1'b0;
	 end
	 else if (S_AXI_BREADY && axi_bvalid) begin
	    aw_en <= 1'b1;
	    axi_awready <= 1'b0;
	 end else begin
	    axi_awready <= 1'b0;
	 end
      end 
   end       

   // Implement axi_awaddr latching
   // This process is used to latch the address when both 
   // S_AXI_AWVALID and S_AXI_WVALID are valid. 

   always @( posedge clk ) begin
      if ( !rstn ) begin
	 axi_awaddr <= 0;
      end else begin    
	 if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
	    // Write Address latching 
	    axi_awaddr <= S_AXI_AWADDR;
	 end
      end 
   end       

   // Implement axi_wready generation
   // axi_wready is asserted for one S_AXI_ACLK clock cycle when both
   // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
   // de-asserted when reset is low. 

   always @( posedge clk ) begin
      if ( !rstn ) begin
	 axi_wready <= 1'b0;
      end else begin    
	 if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en ) begin
	    // slave is ready to accept write data when 
	    // there is a valid write address and write data
	    // on the write address and data bus. This design 
	    // expects no outstanding transactions. 
	    axi_wready <= 1'b1;
	 end else begin
	    axi_wready <= 1'b0;
	 end
      end 
   end       

   // Implement memory mapped register select and write logic generation
   // The write data is accepted and written to memory mapped registers when
   // axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
   // select byte enables of slave registers while writing.
   // These registers are cleared when reset (active low) is applied.
   // Slave register write enable is asserted when valid address and data are available
   // and the slave is ready to accept the write address and write data.
   assign slv_reg_wen = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

   // Output buffers
   localparam BUF_BITS = $clog2(BUFS);

   // inputs to flobuffers
   reg [15:0] 	   flo_data = 0;
   reg [6:0] 	   flo_delay = 0;
   reg [BUFS-1:0]  flo_valid = 0, flo_direct = 0;

   // outputs from flobuffers
   wire [15:0] buf_data[BUFS-1:0];
   wire [BUFS-1:0] buf_err, buf_full, buf_empty, buf_stb;

   genvar      k;
   generate
      for (k = 0; k < BUFS; k = k + 1) begin
	 flobuffer #( .fifo_size(4) ) 
	 flb (
	      .clk(clk),
	      .data_i(flo_data),
	      .delay_i(flo_delay),
	      .valid_i(flo_valid[k]),
	      .direct_i(flo_direct[k]),
	      .data_o(buf_data[k]),
	      .empty_o(buf_empty[k]),
	      .full_o(buf_full[k]),
	      .err_o(buf_err[k]),
	      .stb_o(buf_stb[k])
	      );
      end // for (k = 0; k < BUFS; k = k + 1)
   endgenerate

   // generate RX FIFOs
   // wire rx0_valid = s0_axis_wvalid, rx1_valid = s1_axis_wvalid;
   // wire [23:0] rx0_data = s0_axis_wdata[23:0], rx1_data = s1_axis_wdata[23:0];
   wire [63:0] fifo0_data, fifo1_data;
   reg [31:0] fifo0_data_i = 0, fifo0_data_q = 0;
   reg [31:0] fifo1_data_i = 0, fifo1_data_q = 0;
   reg 	       fifo0_read = 0, fifo1_read = 0;
   wire        fifo0_full, fifo1_full;
   assign rx0_ready = !fifo0_full, rx1_ready = !fifo1_full;
   localparam RX_FIFO_BITS = $clog2(RX_FIFO_LENGTH);
   wire [RX_FIFO_BITS-1:0] fifo0_locs, fifo1_locs;
   
   flofifo #( .LENGTH(RX_FIFO_LENGTH), .WIDTH(64) )
   fifo0(.clk(clk),
	 .data_i(rx0_data),
	 .valid_i(rx0_valid),
	 .read_i(fifo0_read),
	 .data_o(fifo0_data),
	 .locs_o(fifo0_locs),
	 .full_o(fifo0_full)
	 );

   flofifo #( .LENGTH(RX_FIFO_LENGTH), .WIDTH(64) )
   fifo1(.clk(clk),
	 .data_i(rx1_data),
	 .valid_i(rx1_valid),
	 .read_i(fifo1_read),
	 .data_o(fifo1_data),
	 .locs_o(fifo1_locs),
	 .full_o(fifo1_full)
	 );

   // // TODO: can add pipelining here if needed
   assign data_o = buf_data;
   assign stb_o = buf_stb;

   reg [31:0] flo_bram [2**OPT_MEM_ADDR_BITS-1:0]; // main BRAM; 65536 locations by default
   reg [31:0] flo_bram_wdata = 0, flo_bram_wdata_r = 0; // pipelining
   reg 	      flo_bram_wen = 0, flo_bram_wen_r = 0, flo_bram_rd = 0, flo_bram_rd_r = 0, flo_bram_rd_r2 = 0; // pipelining
   reg 	      direct_wen = 0;
   reg [OPT_MEM_ADDR_BITS-1:0] flo_bram_waddr = 0, flo_bram_waddr_r = 0;
   reg [OPT_MEM_ADDR_BITS-1:0] flo_bram_raddr = 0, flo_bram_raddr_r = 0, flo_bram_raddr_r2 = 0;
   reg [31:0] 		       flo_bram_rdata = 0, flo_bram_rdata_r = 0, flo_bram_rdata_r2 = 0;
   wire [OPT_MEM_ADDR_BITS:0] axi_addr = axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS : ADDR_LSB];
   
   /**** Flocra mem and general register write logic ****/
   always @(posedge clk) begin
      // defaults and pipelining
      flo_bram_wen <= 0;
      direct_wen <= 0;
      if (flo_bram_wen) flo_bram[flo_bram_waddr] <= flo_bram_wdata; // can pipeline further if needed (will ultimately use DDR anyway)
   
      if (slv_reg_wen) begin
	 if (axi_addr[OPT_MEM_ADDR_BITS]) begin // upper range: write to BRAM
	    flo_bram_wen <= 1;
	    flo_bram_waddr <= axi_addr[OPT_MEM_ADDR_BITS-1:0]; // BRAM has 16-bit address space by default
	    flo_bram_wdata <= S_AXI_WDATA;
	 end else begin // lower range: write to config registers
	    case (axi_addr[3:0]) // TODO: look at more than lower 4 bits if this is ever expanded
	      // no resets
	      4'd0: slv_reg0 <= S_AXI_WDATA;
	      4'd1: slv_reg1 <= S_AXI_WDATA;
	      4'd2: begin
		 slv_reg2 <= S_AXI_WDATA;
		 direct_wen <= 1;
	      end
	      4'd3: slv_reg3 <= S_AXI_WDATA;
	      default; // no write
	    endcase // case (axi_addr[1:0])
	 end
      end // if (slv_reg_wen)
   end // always @ (posedge clk)

   localparam STATE_BITS = 4;
   localparam IDLE = 4'd0, PREPARE = 4'd1, RUN = 4'd2,
     COUNTDOWN = 4'd3, TRIG = 4'd4, TRIG_FOREVER = 4'd5,
     HALT = 4'd8;
   reg [STATE_BITS-1:0]  state = IDLE;
   wire [BUF_BITS-1:0] buf_idx = flo_bram_rdata_r[24+BUF_BITS-1:24];
   wire [BUF_BITS-1:0] direct_buf_idx = slv_reg2[24+BUF_BITS-1:24];
   reg [23:0] tmr = 0;
   reg 	      trig_r = 0, trig_r1 = 0, trig_r2 = 0, trig_r3 = 0, trig_r4 = 0;
   reg 	      trig_state_change = 0;
   reg [31:0] status_r = 0, status_latch_r = 0, status_latch_r2 = 0, berr_r = 0, bfull_r = 0;
   reg [BUFS-1:0] buf_full_r = 0, buf_empty_r = 0, buf_err_r = 0;
   
   always @(posedge clk) begin
      // pipelining
      {flo_bram_rd_r2, flo_bram_rd_r} <= {flo_bram_rd_r, flo_bram_rd};
      {flo_bram_raddr_r2, flo_bram_raddr_r} <= {flo_bram_raddr_r, flo_bram_raddr};
      status_r <= status_i;
      status_latch_r <= status_latch_i;
      buf_err_r <= buf_err;
      buf_full_r <= buf_full;
      buf_empty_r <= buf_empty;
      {fifo0_data_q, fifo0_data_i} <= fifo0_data;
      {fifo1_data_q, fifo1_data_i} <= fifo1_data;      

      // triggering -- could be an external input, so need decent synch
      {trig_r4, trig_r3, trig_r2, trig_r} <= {trig_r3, trig_r2, trig_r, trig_i};
      trig_state_change <= trig_r3 != trig_r4; // may want to have more hysteresis

      // data output logic
      // state <= IDLE; // default state      
      flo_bram_rd <= 0; // default
      flo_valid <= 0; // default
      // always read from BRAM
      flo_bram_rdata <= flo_bram[flo_bram_raddr]; // can pipeline this further
      flo_bram_rdata_r <= flo_bram_rdata; // can pipeline this further
      case (state)
	default: begin // IDLE state	   
	   if (direct_wen) begin
	      flo_delay <= 0; // don't see a reason to ever use nonzero delay here
	      flo_valid[direct_buf_idx] <= 1;
	      flo_data <= slv_reg2[15:0];
	   end
	   
	   if (run_fsm) begin
	      state <= PREPARE;
	      flo_bram_raddr <= flo_bram_raddr + 1; // next address
	   end else begin	      
	      flo_bram_raddr <= 0; // reset PC
	   end
	end
	// catch-all state to ensure the instruction data in the BRAM pipeline is valid
	// (not yet used, but may be useful for branches etc in the future)	
	PREPARE: begin
	   flo_bram_raddr <= flo_bram_raddr + 1;
	   if (stop_fsm) state <= HALT;
	   else state <= RUN;
	end
	RUN: begin
	   if (flo_bram_rdata_r[31]) begin // data to buffers
	      // TODO: pipelining here if needed
	      flo_valid[buf_idx] <= 1;
	      flo_delay <= flo_bram_rdata_r[22:16];
	      flo_data <= flo_bram_rdata_r[15:0];
	      flo_bram_raddr <= flo_bram_raddr + 1; // next address	      
	   end else begin // general-purpose instructions
	      case (flo_bram_rdata_r[30:24])
		default: begin
		   flo_bram_raddr <= flo_bram_raddr + 1; // next address
		end
		INSTR_FINISH: begin
		   state <= HALT;
		   // flo_bram_raddr <= flo_bram_raddr; // backtrack due to delay (not strictly necessary here)
		end
		INSTR_WAIT: begin
		   state <= COUNTDOWN;
		   tmr <= flo_bram_rdata_r[23:0];
		   flo_bram_raddr <= flo_bram_raddr - 1; // backtrack due to delay
		end
		INSTR_TRIG: begin
		   state <= TRIG;
		   tmr <= flo_bram_rdata_r[23:0]; // trigger timeout, in case it never arrives
		   flo_bram_raddr <= flo_bram_raddr - 1; // backtrack due to delay
		end
		INSTR_TRIG_FOREVER: begin
		   state <= TRIG_FOREVER;
		   flo_bram_raddr <= flo_bram_raddr - 1; // backtrack due to delay
		end
		// TODO: add an INSTR_TRIG_FOREVER as well that has no timeout
	      endcase
	   end
	end // case: RUN
	HALT: begin
	   if (!run_fsm) begin
	      state <= IDLE;
	   end	   
	end
	COUNTDOWN: begin
	   if (tmr == 0) begin
	      state <= PREPARE;
	      flo_bram_raddr <= flo_bram_raddr + 1;
	   end else tmr <= tmr - 1;
	end
	TRIG: begin
	   if (trig_state_change || (tmr == 0)) begin
	      tmr <= 0;
	      state <= PREPARE;
	      flo_bram_raddr <= flo_bram_raddr + 1;
	   end else tmr <= tmr - 1;
	end
	TRIG_FOREVER: begin
	   if (trig_state_change || !run_fsm) begin
	      state <= PREPARE;
	      flo_bram_raddr <= flo_bram_raddr + 1;
	   end
	end
      endcase // case (state)
     
      // monitoring/error info
      // slv_reg4 <= {{(32-OPT_MEM_ADDR_BITS-STATE_BITS){1'b0}}, flo_bram_raddr_r2, state};
      slv_reg4 <= { {8-STATE_BITS{1'd0}}, state, 
		    {24-OPT_MEM_ADDR_BITS{1'd0}}, flo_bram_raddr_r2};
      slv_reg5 <= status_r;
      slv_reg6 <= status_latch_r2;
      slv_reg7 <= berr_r;
      slv_reg8 <= bfull_r;
      slv_reg9 <= {8'd0, buf_empty_r};
      slv_reg10 <= { {16-RX_FIFO_BITS{1'b0}}, fifo1_locs, {16-RX_FIFO_BITS{1'b0}}, fifo0_locs};
      slv_reg11 <= fifo0_data_i;
      slv_reg12 <= fifo1_data_i;
      slv_reg13 <= fifo0_data_q;
      slv_reg14 <= fifo1_data_q;
      slv_reg15 <= 0;

      // default register values; modified on read
      fifo0_read <= 0;
      fifo1_read <= 0;
      status_latch_r2 <= status_latch_r2 | status_latch_r;
      berr_r <= berr_r | {8'd0, buf_err_r};
      bfull_r <= bfull_r | {8'd0, buf_full_r};
      // bempty_r <= bempty_r | {8'd0, buf_empty_r};

      // Do various things when registers are read
      if (slv_reg_rden) begin
	 case ( axi_araddr[ADDR_LSB+3:ADDR_LSB] )
	   4'd6: status_latch_r2 <= 0;
	   4'd7: berr_r <= 0;
	   4'd8: bfull_r <= 0;
	   4'd11: fifo0_read <= 1; // pops next value from FIFO
	   4'd12: fifo1_read <= 1; // pops next value from FIFO
	   default; // do nothing
	 endcase // case ( axi_araddr[ADDR_LSB+3:ADDR_LSB] )
      end      
   end
   
   // Implement write response logic generation
   // The write response and response valid signals are asserted by the slave 
   // when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
   // This marks the acceptance of address and indicates the status of 
   // write transaction.

   always @( posedge clk ) begin
      if ( !rstn ) begin
	 axi_bvalid  <= 0;
	 axi_bresp   <= 2'b0;
      end else begin    
	 if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID) begin
	    // indicates a valid write response is available
	    axi_bvalid <= 1'b1;
	    axi_bresp  <= 2'b0; // 'OKAY' response 
	 end else begin                  // work error responses in future
	    if (S_AXI_BREADY && axi_bvalid) begin
	       //check if bready is asserted while bvalid is high) 
	       //(there is a possibility that bready is always asserted high)   
	       axi_bvalid <= 1'b0; 
	    end  
	 end
      end
   end   

   // Implement axi_arready generation
   // axi_arready is asserted for one S_AXI_ACLK clock cycle when
   // S_AXI_ARVALID is asserted. axi_awready is 
   // de-asserted when reset (active low) is asserted. 
   // The read address is also latched when S_AXI_ARVALID is 
   // asserted. axi_araddr is reset to zero on reset assertion.

   always @( posedge clk ) begin
      if ( !rstn ) begin
	 axi_arready <= 1'b0;
	 axi_araddr  <= 0;
      end else begin    
	 if (~axi_arready && S_AXI_ARVALID) begin
	    // indicates that the slave has acceped the valid read address
	    axi_arready <= 1'b1;
	    // Read address latching
	    axi_araddr  <= S_AXI_ARADDR;
	 end else begin
	    axi_arready <= 1'b0;
	 end
      end 
   end       

   // Implement axi_arvalid generation
   // axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
   // S_AXI_ARVALID and axi_arready are asserted. The slave registers 
   // data are available on the axi_rdata bus at this instance. The 
   // assertion of axi_rvalid marks the validity of read data on the 
   // bus and axi_rresp indicates the status of read transaction.axi_rvalid 
   // is deasserted on reset (active low). axi_rresp and axi_rdata are 
   // cleared to zero on reset (active low).  
   always @( posedge clk ) begin
      if ( !rstn ) begin
	 axi_rvalid <= 0;
	 axi_rresp  <= 0;
      end else begin    
	 if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
	    // Valid read data is available at the read data bus
	    axi_rvalid <= 1'b1;
	    axi_rresp  <= 2'b0; // 'OKAY' response
	 end   
	 else if (axi_rvalid && S_AXI_RREADY)
	   begin
	      // Read data is accepted by the master
	      axi_rvalid <= 1'b0;
	   end                
      end
   end    

   // Implement memory mapped register select and read logic generation
   // Slave register read enable is asserted when valid address is available
   // and the slave is ready to accept the read address.
   assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
   always @( axi_araddr[ADDR_LSB+3:ADDR_LSB] ) begin
      // Address decoding for reading registers
      // case ( axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
      case ( axi_araddr[ADDR_LSB+3:ADDR_LSB] )
	4'h0   : reg_data_out = slv_reg0;
	4'h1   : reg_data_out = slv_reg1;
	4'h2   : reg_data_out = slv_reg2;
	4'h3   : reg_data_out = slv_reg3;
	4'h4   : reg_data_out = slv_reg4;
	4'h5   : reg_data_out = slv_reg5;
	4'h6   : reg_data_out = slv_reg6;
	4'h7   : reg_data_out = slv_reg7;
	4'h8   : reg_data_out = slv_reg8;
	4'h9   : reg_data_out = slv_reg9;
	4'ha   : reg_data_out = slv_reg10;
	4'hb   : reg_data_out = slv_reg11;
	4'hc   : reg_data_out = slv_reg12;
	4'hd   : reg_data_out = slv_reg13;
	4'he   : reg_data_out = slv_reg14;
	default: reg_data_out = slv_reg15;
      endcase
   end

   // Output register or memory read data, and error bits
   always @( posedge clk ) begin
      // When there is a valid read address (S_AXI_ARVALID) with 
      // acceptance of read address by the slave (axi_arready), 
      // output the read data 
      if (slv_reg_rden) axi_rdata <= reg_data_out;     // register read data
   end

endmodule // flodecode
`endif //  `ifndef _FLODECODE_
