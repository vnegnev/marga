//-----------------------------------------------------------------------------
// Title         : rx_chain_model
// Project       : flocra
//-----------------------------------------------------------------------------
// File          : rx_chain_model.v
// Author        :   <vlad@vlad-laptop>
// Created       : 25.12.2020
// Last modified : 25.12.2020
//-----------------------------------------------------------------------------
// Description :
//
// Basic model to replace the Xilinx IP involved in the RX chain;
// doesn't do any RX but simulates the data flow.
//
//-----------------------------------------------------------------------------
// Copyright (c) 2020 by OCRA developers This model is the confidential and
// proprietary property of OCRA developers and the possession or use of this
// file requires a written license from OCRA developers.
//------------------------------------------------------------------------------
// Modification history :
// 25.12.2020 : created
//-----------------------------------------------------------------------------

`ifndef _RX_CHAIN_MODEL_
 `define _RX_CHAIN_MODEL_

 `timescale 1ns/1ns

module rx_chain_model(
		      input 		clk,
		      input 		rst_n,

		      input [15:0] 	rate_axis_tdata_i,
		      input 		rate_axis_tvalid_i,

		      input [31:0] 	dds_iq_axis_tdata_i,
		      input 		dds_iq_axis_tvalid_i, 

		      input 		axis_tready_i,
		      output reg 	axis_tvalid_o,
		      output reg [31:0] axis_tdata_o
		      );

   reg [11:0] 				cnt = 0;

   initial axis_tdata_o = 0;
   
   always @(posedge clk) begin
      axis_tvalid_o <= 0;
      if (!rst_n) cnt <= 0;
      else begin
	 cnt <= cnt + 1;
	 if (cnt == rate_axis_tdata_i[11:0] - 1) begin
	    axis_tvalid_o <= 1;
	    axis_tdata_o <= dds_iq_axis_tdata_i;
	    cnt <= 0;
	 end
      end
   end

endmodule // rx_chain_model
`endif //  `ifndef _RX_CHAIN_MODEL_
