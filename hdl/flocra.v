//-----------------------------------------------------------------------------
// Title         : flocra
// Project       : flocra
//-----------------------------------------------------------------------------
// File          : flocra.v
// Author        :   <vlad@arch-ssd>
// Created       : 17.12.2020
// Last modified : 17.12.2020
//-----------------------------------------------------------------------------
// Description :
//
// Top-level flocra core file.
//
// Outputs: 
// - direct SPI lines to the gradient boards
// - direct SPI/I2C? lines to the attenuator core [TODO]
// - external trigger output
// - phase words to three external DDS cores
// - I/Q data to two external complex multipliers
// - LO source, decimation factor and reset gating to the two RX channels
//
// Inputs:
// - 2x 32-bit downconverted data streams
// - ADC line from GPA-FHDO
// - external trigger input
// 
// Internal structure:
// - flodecode core, responsible for outputs and their timing, and RX FIFOs
// - resetting and phase offsetting/incrementing is handled here for
// the TX DDSes and their routing
// 
// -----------------------------------------------------------------------------
// See LICENSE for GPL licensing information
// ------------------------------------------------------------------------------
// Modification history : 17.12.2020 : created
// -----------------------------------------------------------------------------

`ifndef _FLOCRA_
 `define _FLOCRA_

 `include "flodecode.v"
 `include "flobuffer.v"
 `include "ocra1_iface.v"
 `include "gpa_fhdo_iface.v"

 `timescale 1ns / 1ns

module flocra #
  (
   // Users to add parameters here
   // User parameters ends
   )
   (
    // Outputs to the OCRA1 board (concatenation on the expansion header etc will be handled in Vivado's block diagram)
    output 				  oc1_clk_o, // SPI clock
    output 				  oc1_syncn_o, // sync (roughly equivalent to SPI CS)
    output 				  oc1_ldacn_o, // ldac
    output 				  oc1_sdox_o, // data out, X DAC
    output 				  oc1_sdoy_o, // data out, Y DAC
    output 				  oc1_sdoz_o, // data out, Z DAC
    output 				  oc1_sdoz2_o, // data out, Z2 DAC

    // I/O to the GPA-FHDO board
    output 				  fhd_clk_o, // SPI clock
    output 				  fhd_sdo_o, // data out
    output 				  fhd_ssn_o, // SPI CS
    input 				  fhd_sdi_i, // data in

    // Outputs to the attenuator chip on the ocra1
    // TODO

    // Outputs to the TX and RX digital gates
    output 				  tx_gate_o,
    output 				  rx_gate_o,

    // TX DDS phase control
    output reg [24:0] 			  dds0_phase, dds1_phase, dds2_phase,

    // RX DDS channel multiplexing
    // TODO HERE

    // RX reset, CIC decimation ratio control (from 1 to 1023)
    output 				  rx0_rst_n, rx1_rst_n, 
    output [9:0] 			  rx0_rate_o, rx1_rate_o,

    // External trigger output and input
    output 				  trig_o,
    input 				  trig_i,
   
    // User ports ends
    // Do not modify the ports beyond this line

    // Ports of Axi Slave Bus Interface S0_AXI
    input 				  s0_axi_aclk,
    input 				  s0_axi_aresetn,
    input [C_S0_AXI_ADDR_WIDTH-1 : 0] 	  s0_axi_awaddr,
    input [2 : 0] 			  s0_axi_awprot,
    input 				  s0_axi_awvalid,
    output 				  s0_axi_awready,
    input [C_S0_AXI_DATA_WIDTH-1 : 0] 	  s0_axi_wdata,
    input [(C_S0_AXI_DATA_WIDTH/8)-1 : 0] s0_axi_wstrb,
    input 				  s0_axi_wvalid,
    output 				  s0_axi_wready,
    output [1 : 0] 			  s0_axi_bresp,
    output 				  s0_axi_bvalid,
    input 				  s0_axi_bready,
    input [C_S0_AXI_ADDR_WIDTH-1 : 0] 	  s0_axi_araddr,
    input [2 : 0] 			  s0_axi_arprot,
    input 				  s0_axi_arvalid,
    output 				  s0_axi_arready,
    output [C_S0_AXI_DATA_WIDTH-1 : 0] 	  s0_axi_rdata,
    output [1 : 0] 			  s0_axi_rresp,
    output 				  s0_axi_rvalid,
    input 				  s0_axi_rready,

    );

   // Parameters of Axi Slave Bus Interface S0_AXI
   localparam integer 			      C_S0_AXI_DATA_WIDTH = 32;
   localparam integer 			      C_S0_AXI_ADDR_WIDTH = 19;
   wire 				      clk = s0_axi_aclk;

   // Interface connections
   wire [31:0] 				      gpa_data;
   wire 				      ocra1_data_valid, fhdo_data_valid;
   wire [5:0] 				      spi_clk_div;
   wire [15:0] 				      fhdo_adc; // ADC data from GPA-FHDO

   // for the ocra1, data can be written even while it's outputting to
   // SPI - for the fhd, this isn't the case. So don't use the
   // oc1_busy line in grad_bram, since it would mean that false
   // errors would get flagged - just fhd_busy for now.
   wire 				      fhd_busy;
   wire 				      oc1_busy, oc1_data_lost;      
   
   ocra1_iface ocra1_if (
			 // Outputs
			 .oc1_clk_o	(oc1_clk_o),
			 .oc1_syncn_o	(oc1_syncn_o),
			 .oc1_ldacn_o	(oc1_ldacn_o),
			 .oc1_sdox_o	(oc1_sdox_o),
			 .oc1_sdoy_o	(oc1_sdoy_o),
			 .oc1_sdoz_o	(oc1_sdoz_o),
			 .oc1_sdoz2_o	(oc1_sdoz2_o),
			 .busy_o       	(oc1_busy),
			 .data_lost_o   (oc1_data_lost),
			 // Inputs
			 .clk		(clk),
			 .rst_n         (grad_bram_enb_i), // purely for clearing data_lost for initial word
			 .data_i       	(data),
			 .valid_i      	(oc1_data_valid),
			 .spi_clk_div_i	(spi_clk_div));
   
   gpa_fhdo_iface gpa_fhdo_if (
			       // Outputs
			       .fhd_clk_o	(fhd_clk_o),
			       .fhd_sdo_o	(fhd_sdo_o),
			       .fhd_csn_o	(fhd_ssn_o),
			       .busy_o		(fhd_busy),
			       .adc_value_o	(fhd_adc),
			       // Inputs
			       .clk		(clk),
			       .data_i		(data),
			       .spi_clk_div_i	(spi_clk_div),
			       .valid_i		(gpa_fhdo_data_valid),
			       .fhd_sdi_i	(fhd_sdi_i));


   ///////////////////////// FLODECODE ////////////////////////////
     wire [15:0] fld_data[23:0];
   wire [23:0] 	 fld_stb;
   
       flodecode #(.BUFS(24), .RX_FIFO_LENGTH(16384))
   fld (
	.trig_i(trig_i),
	.status_i({16'd0, fhdo_adc}), // spare bits available for external status
	.status_latch_i({29'd0, fhd_busy, oc1_busy, oc1_data_lost}),
	.data_o(fld_data),
	.stb_o(fld_stb),

	.rx0_data(s1_axis_wdata)
	.rx0_valid(s1_axis_wvalid)
	.rx0_ready(s1_axis_wready),

	.rx1_data(s2_axis_wdata)
	.rx1_valid(s2_axis_wvalid)
	.rx1_ready(s2_axis_wready),

	.S_AXI_ACLK			(S0_AXI_ACLK),
	.S_AXI_ARESETN			(S0_AXI_ARESETN),
	.S_AXI_AWADDR			(S0_AXI_AWADDR[C_S0_AXI_ADDR_WIDTH-1:0]),
	.S_AXI_AWPROT			(S0_AXI_AWPROT[2:0]),
	.S_AXI_AWVALID			(S0_AXI_AWVALID),
	.S_AXI_WDATA			(S0_AXI_WDATA[C_S0_AXI_DATA_WIDTH-1:0]),
	.S_AXI_WSTRB			(S0_AXI_WSTRB[(C_S0_AXI_DATA_WIDTH/8)-1:0]),
	.S_AXI_WVALID			(S0_AXI_WVALID),
	.S_AXI_BREADY			(S0_AXI_BREADY),
	.S_AXI_ARADDR			(S0_AXI_ARADDR[C_S0_AXI_ADDR_WIDTH-1:0]),
	.S_AXI_ARPROT			(S0_AXI_ARPROT[2:0]),
	.S_AXI_ARVALID			(S0_AXI_ARVALID),
	.S_AXI_RREADY			(S0_AXI_RREADY)
	);
	

	

endmodule
`endif //  `ifndef _OCRA_GRAD_CTRL_
