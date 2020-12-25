//-----------------------------------------------------------------------------
// Title         : flocra_simple_tb
// Project       : flocra
//-----------------------------------------------------------------------------
// File          : flocra_simple_tb.v
// Author        :   <vlad@vlad-laptop>
// Created       : 25.12.2020
// Last modified : 25.12.2020
//-----------------------------------------------------------------------------
// Description :
//
// Low-level testbench for flocra, mainly to help with HDL design
// rather to exercise all possible functionality.
//
//-----------------------------------------------------------------------------
// Copyright (c) 2020 by OCRA developers This model is the confidential and
// proprietary property of OCRA developers and the possession or use of this
// file requires a written license from OCRA developers.
//------------------------------------------------------------------------------
// Modification history :
// 25.12.2020 : created
//-----------------------------------------------------------------------------

`ifndef _FLOCRA_SIMPLE_TB_
 `define _FLOCRA_SIMPLE_TB_

 `include "flocra.v"
 `include "ocra1_model.v"
 `include "gpa_fhdo_model.v"

 `timescale 1ns/1ns

module flocra_simple_tb;
   localparam C_S0_AXI_ADDR_WIDTH = 19, C_S0_AXI_DATA_WIDTH = 32;

   reg err = 0;
   /*AUTOREGINPUT*/
   // Beginning of automatic reg inputs (for undeclared instantiated-module inputs)
   reg			fhdo_sdi_i;		// To UUT of flocra.v
   reg [31:0]		rx0_axis_tdata_i;	// To UUT of flocra.v
   reg			rx0_axis_tvalid_i;	// To UUT of flocra.v
   reg [31:0]		rx1_axis_tdata_i;	// To UUT of flocra.v
   reg			rx1_axis_tvalid_i;	// To UUT of flocra.v
   reg			s0_axi_aclk;		// To UUT of flocra.v
   reg [C_S0_AXI_ADDR_WIDTH-1:0] s0_axi_araddr;	// To UUT of flocra.v
   reg			s0_axi_aresetn;		// To UUT of flocra.v
   reg [2:0]		s0_axi_arprot;		// To UUT of flocra.v
   reg			s0_axi_arvalid;		// To UUT of flocra.v
   reg [C_S0_AXI_ADDR_WIDTH-1:0] s0_axi_awaddr;	// To UUT of flocra.v
   reg [2:0]		s0_axi_awprot;		// To UUT of flocra.v
   reg			s0_axi_awvalid;		// To UUT of flocra.v
   reg			s0_axi_bready;		// To UUT of flocra.v
   reg			s0_axi_rready;		// To UUT of flocra.v
   reg [C_S0_AXI_DATA_WIDTH-1:0] s0_axi_wdata;	// To UUT of flocra.v
   reg [(C_S0_AXI_DATA_WIDTH/8)-1:0] s0_axi_wstrb;// To UUT of flocra.v
   reg			s0_axi_wvalid;		// To UUT of flocra.v
   reg			trig_i;			// To UUT of flocra.v
   // End of automatics
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [24:0]		dds0_phase_o;		// From UUT of flocra.v
   wire [24:0]		dds1_phase_o;		// From UUT of flocra.v
   wire [24:0]		dds2_phase_o;		// From UUT of flocra.v
   wire			fhdo_clk_o;		// From UUT of flocra.v
   wire			fhdo_sdo_o;		// From UUT of flocra.v
   wire			fhdo_ssn_o;		// From UUT of flocra.v
   wire			ocra1_clk_o;		// From UUT of flocra.v
   wire			ocra1_ldacn_o;		// From UUT of flocra.v
   wire			ocra1_sdox_o;		// From UUT of flocra.v
   wire			ocra1_sdoy_o;		// From UUT of flocra.v
   wire			ocra1_sdoz2_o;		// From UUT of flocra.v
   wire			ocra1_sdoz_o;		// From UUT of flocra.v
   wire			ocra1_syncn_o;		// From UUT of flocra.v
   wire			rx0_axis_tready_o;	// From UUT of flocra.v
   wire [1:0]		rx0_dds_source_o;	// From UUT of flocra.v
   wire [9:0]		rx0_rate_o;		// From UUT of flocra.v
   wire			rx0_rst_n_o;		// From UUT of flocra.v
   wire			rx1_axis_tready_o;	// From UUT of flocra.v
   wire [1:0]		rx1_dds_source_o;	// From UUT of flocra.v
   wire [9:0]		rx1_rate_o;		// From UUT of flocra.v
   wire			rx1_rst_n_o;		// From UUT of flocra.v
   wire			rx_gate_o;		// From UUT of flocra.v
   wire			s0_axi_arready;		// From UUT of flocra.v
   wire			s0_axi_awready;		// From UUT of flocra.v
   wire [1:0]		s0_axi_bresp;		// From UUT of flocra.v
   wire			s0_axi_bvalid;		// From UUT of flocra.v
   wire [C_S0_AXI_DATA_WIDTH-1:0] s0_axi_rdata;	// From UUT of flocra.v
   wire [1:0]		s0_axi_rresp;		// From UUT of flocra.v
   wire			s0_axi_rvalid;		// From UUT of flocra.v
   wire			s0_axi_wready;		// From UUT of flocra.v
   wire			trig_o;			// From UUT of flocra.v
   wire [31:0]		tx0_axis_tdata_o;	// From UUT of flocra.v
   wire			tx0_axis_tvalid_o;	// From UUT of flocra.v
   wire [31:0]		tx1_axis_tdata_o;	// From UUT of flocra.v
   wire			tx1_axis_tvalid_o;	// From UUT of flocra.v
   wire			tx_gate_o;		// From UUT of flocra.v
   // End of automatics

   wire [17:0] 		ocra1_voutx, ocra1_vouty, ocra1_voutz, ocra1_voutz2;
   wire [17:0] 		fhdo_voutx, fhdo_vouty, fhdo_voutz, fhdo_voutz2;   

   wire 		clk = s0_axi_aclk;
   always #5 s0_axi_aclk = !s0_axi_aclk;
   integer k;
   
   initial begin
      $dumpfile("icarus_compile/000_flocra_simple_tb.lxt");
      $dumpvars(0, flocra_simple_tb);

      s0_axi_aclk = 1;

      #5000 if (err) begin
	 $display("THERE WERE ERRORS");
	 $stop; // to return a nonzero error code if the testbench is later scripted at a higher level
      end
      $finish;
   end // initial begin
   
   // Tasks for AXI bus reads and writes
   task wr32; //write to bus
      input [31:0] addr, data;
      begin
         #10 s0_axi_wdata = data;
	 s0_axi_wstrb = 'hf;
         s0_axi_awaddr = addr;
         s0_axi_awvalid = 1;
         s0_axi_wvalid = 1;
         fork
            begin: wait_axi_write
               wait(s0_axi_awready && s0_axi_wready);
               disable axi_write_timeout;
            end
            begin: axi_write_timeout
               #10000 disable wait_axi_write;
	       $display("%d ns: AXI write timed out", $time);
            end
         join
         #13 s0_axi_awvalid = 0;
         s0_axi_wvalid = 0;
      end
   endtask // wr32

   task rd32; //read from bus
      input [31:0] addr;
      input [31:0] expected;
      begin
         #10 s0_axi_arvalid = 1;
         s0_axi_araddr = addr;
         wait(s0_axi_arready);
         #13 s0_axi_arvalid = 0;
         wait(s0_axi_rvalid);
         #13 if (expected !== s0_axi_rdata) begin
            $display("%d ns: Bus read error, address %x, expected output %x, read %x.",
		     $time, addr, expected, s0_axi_rdata);
            err <= 1'd1;
         end
         s0_axi_rready = 1;
         s0_axi_arvalid = 0;
         #10 s0_axi_rready = 0;
      end
   endtask // rd32

   ocra1_model #(/*AUTOINSTPARAM*/)
   ocra1(
	 // Outputs
	 .voutx				(ocra1_voutx[17:0]),
	 .vouty				(ocra1_vouty[17:0]),
	 .voutz				(ocra1_voutz[17:0]),
	 .voutz2			(ocra1_voutz2[17:0]),
	 // Inputs
	 .clk				(clk),
	 .syncn				(ocra1_syncn_o),
	 .ldacn				(ocra1_ldacn_o),
	 .sdox				(ocra1_sdox_o),
	 .sdoy				(ocra1_sdoy_o),
	 .sdoz				(ocra1_sdoz_o),
	 .sdoz2				(ocra1_sdoz2_o));

   gpa_fhdo_model #(/*AUTOINSTPARAM*/)
   fhdo(
	// Outputs
	.sdi				(fhdo_sdi_i),
	.voutx				(fhdo_voutx[15:0]),
	.vouty				(fhdo_vouty[15:0]),
	.voutz				(fhdo_voutz[15:0]),
	.voutz2				(fhdo_voutz2[15:0]),
	// Inputs
	.clk				(clk),
	.csn				(fhdo_ssn_o),
	.sdo				(fhdo_sdo_o));
   
   flocra #(/*AUTOINSTPARAM*/)
   UUT(/*AUTOINST*/
       // Outputs
       .ocra1_clk_o			(ocra1_clk_o),
       .ocra1_syncn_o			(ocra1_syncn_o),
       .ocra1_ldacn_o			(ocra1_ldacn_o),
       .ocra1_sdox_o			(ocra1_sdox_o),
       .ocra1_sdoy_o			(ocra1_sdoy_o),
       .ocra1_sdoz_o			(ocra1_sdoz_o),
       .ocra1_sdoz2_o			(ocra1_sdoz2_o),
       .fhdo_clk_o			(fhdo_clk_o),
       .fhdo_sdo_o			(fhdo_sdo_o),
       .fhdo_ssn_o			(fhdo_ssn_o),
       .tx_gate_o			(tx_gate_o),
       .rx_gate_o			(rx_gate_o),
       .dds0_phase_o			(dds0_phase_o[24:0]),
       .dds1_phase_o			(dds1_phase_o[24:0]),
       .dds2_phase_o			(dds2_phase_o[24:0]),
       .rx0_rst_n_o			(rx0_rst_n_o),
       .rx1_rst_n_o			(rx1_rst_n_o),
       .rx0_rate_o			(rx0_rate_o[9:0]),
       .rx1_rate_o			(rx1_rate_o[9:0]),
       .trig_o				(trig_o),
       .rx0_axis_tready_o		(rx0_axis_tready_o),
       .rx0_dds_source_o		(rx0_dds_source_o[1:0]),
       .rx1_axis_tready_o		(rx1_axis_tready_o),
       .rx1_dds_source_o		(rx1_dds_source_o[1:0]),
       .tx0_axis_tdata_o		(tx0_axis_tdata_o[31:0]),
       .tx0_axis_tvalid_o		(tx0_axis_tvalid_o),
       .tx1_axis_tdata_o		(tx1_axis_tdata_o[31:0]),
       .tx1_axis_tvalid_o		(tx1_axis_tvalid_o),
       .s0_axi_awready			(s0_axi_awready),
       .s0_axi_wready			(s0_axi_wready),
       .s0_axi_bresp			(s0_axi_bresp[1:0]),
       .s0_axi_bvalid			(s0_axi_bvalid),
       .s0_axi_arready			(s0_axi_arready),
       .s0_axi_rdata			(s0_axi_rdata[C_S0_AXI_DATA_WIDTH-1:0]),
       .s0_axi_rresp			(s0_axi_rresp[1:0]),
       .s0_axi_rvalid			(s0_axi_rvalid),
       // Inputs
       .fhdo_sdi_i			(fhdo_sdi_i),
       .trig_i				(trig_i),
       .rx0_axis_tvalid_i		(rx0_axis_tvalid_i),
       .rx0_axis_tdata_i		(rx0_axis_tdata_i[31:0]),
       .rx1_axis_tvalid_i		(rx1_axis_tvalid_i),
       .rx1_axis_tdata_i		(rx1_axis_tdata_i[31:0]),
       .s0_axi_aclk			(s0_axi_aclk),
       .s0_axi_aresetn			(s0_axi_aresetn),
       .s0_axi_awaddr			(s0_axi_awaddr[C_S0_AXI_ADDR_WIDTH-1:0]),
       .s0_axi_awprot			(s0_axi_awprot[2:0]),
       .s0_axi_awvalid			(s0_axi_awvalid),
       .s0_axi_wdata			(s0_axi_wdata[C_S0_AXI_DATA_WIDTH-1:0]),
       .s0_axi_wstrb			(s0_axi_wstrb[(C_S0_AXI_DATA_WIDTH/8)-1:0]),
       .s0_axi_wvalid			(s0_axi_wvalid),
       .s0_axi_bready			(s0_axi_bready),
       .s0_axi_araddr			(s0_axi_araddr[C_S0_AXI_ADDR_WIDTH-1:0]),
       .s0_axi_arprot			(s0_axi_arprot[2:0]),
       .s0_axi_arvalid			(s0_axi_arvalid),
       .s0_axi_rready			(s0_axi_rready));
endmodule // flocra_simple_tb
`endif //  `ifndef _FLOCRA_SIMPLE_TB_
