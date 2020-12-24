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
// - flodecoder core, responsible for outputs and their timing
// - resetting and phase offsetting/incrementing is handled here for the DDSes
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
    // Users to add ports here
    input [13:0] 			      grad_bram_offset_i,
    input 				      grad_bram_enb_i, // enable core execution

    // Outputs to the OCRA1 board (concatenation on the expansion header etc will be handled in Vivado's block diagram)
    output 				      oc1_clk_o, // SPI clock
    output 				      oc1_syncn_o, // sync (roughly equivalent to SPI CS)
    output 				      oc1_ldacn_o, // ldac
    output 				      oc1_sdox_o, // data out, X DAC
    output 				      oc1_sdoy_o, // data out, Y DAC
    output 				      oc1_sdoz_o, // data out, Z DAC
    output 				      oc1_sdoz2_o, // data out, Z2 DAC

    // I/O to the GPA-FHDO board
    output 				      fhd_clk_o, // SPI clock
    output 				      fhd_sdo_o, // data out
    output 				      fhd_ssn_o, // SPI CS
    input 				      fhd_sdi_i, // data in
   
    // User ports ends
    // Do not modify the ports beyond this line

    // Ports of Axi Slave Bus Interface S00_AXI
    input 				      s00_axi_aclk,
    input 				      s00_axi_aresetn,
    input [C_S00_AXI_ADDR_WIDTH-1 : 0] 	      s00_axi_awaddr,
    input [2 : 0] 			      s00_axi_awprot,
    input 				      s00_axi_awvalid,
    output 				      s00_axi_awready,
    input [C_S00_AXI_DATA_WIDTH-1 : 0] 	      s00_axi_wdata,
    input [(C_S00_AXI_DATA_WIDTH/8)-1 : 0]    s00_axi_wstrb,
    input 				      s00_axi_wvalid,
    output 				      s00_axi_wready,
    output [1 : 0] 			      s00_axi_bresp,
    output 				      s00_axi_bvalid,
    input 				      s00_axi_bready,
    input [C_S00_AXI_ADDR_WIDTH-1 : 0] 	      s00_axi_araddr,
    input [2 : 0] 			      s00_axi_arprot,
    input 				      s00_axi_arvalid,
    output 				      s00_axi_arready,
    output [C_S00_AXI_DATA_WIDTH-1 : 0]       s00_axi_rdata,
    output [1 : 0] 			      s00_axi_rresp,
    output 				      s00_axi_rvalid,
    input 				      s00_axi_rready,

    );

   // Parameters of Axi Slave Bus Interface S00_AXI
   localparam integer 			      C_S00_AXI_DATA_WIDTH = 32;
   localparam integer 			      C_S00_AXI_ADDR_WIDTH = 24;

   // Interface connections
   wire [31:0] 				      data;
   wire [3:0]				      data_valid;
   wire 				      oc1_data_valid = data_valid[0], gpa_fhdo_data_valid = data_valid[1];
   wire [5:0] 				      spi_clk_div;
   wire 				      clk = s00_axi_aclk; // alias
   wire [15:0] 				      fhd_adc; // ADC data from GPA-FHDO

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

endmodule
`endif //  `ifndef _OCRA_GRAD_CTRL_
