//-----------------------------------------------------------------------------
// Title         : flofifo
// Project       : flocra
//-----------------------------------------------------------------------------
// File          : flofifo.v
// Author        :   <vlad@vlad-laptop>
// Created       : 24.12.2020
// Last modified : 24.12.2020
//-----------------------------------------------------------------------------
// Description :
// RX FIFO to be used as part of flocra
//-----------------------------------------------------------------------------
// Copyright (c) 2020 by OCRA developers This model is the confidential and
// proprietary property of OCRA developers and the possession or use of this
// file requires a written license from OCRA developers.
//------------------------------------------------------------------------------
// Modification history :
// 24.12.2020 : created
//-----------------------------------------------------------------------------

`ifndef _FLOFIFO_
 `define _FLOFIFO_

 `timescale 1ns/1ns

module flofifo #
  (
   parameter LENGTH = 16384,
   parameter WIDTH = 24
   )
   (
    input clk,
    input [WIDTH-1:0] data_i,
    input valid_i,

    input read_i, // output data was read, want to read next sample

    output reg [WIDTH-1:0] data_o,
    output reg valid_o, // data ready to be read

    output reg [$clog2(LENGTH)-1:0] locs_o,
    output reg empty_o, full_o//, err_empty_o, err_full_o
    );

   initial begin
      data_o = 0;
      valid_o = 0;
      locs_o = 0;
      empty_o = 1;
      full_o = 0;
   end

   localparam ADDR_BITS = $clog2(LENGTH);
   reg [WIDTH-1:0] fifo_mem[LENGTH-1:0];
   reg [WIDTH-1:0] data_r = 0;
   reg [WIDTH-1:0] out_data_r = 0;
   reg [ADDR_BITS-1:0] in_ptr = 0, out_ptr = 0;
   reg [ADDR_BITS-1:0] ptr_diff = 0, ptr_diff_r = 0;
   reg 		       valid_r = 0, read_r = 0;

   always @(posedge clk) begin
      // TODO: encode stream more efficiently in 32b
      data_r <= data_i;
      // in_ptr_r <= in_ptr;
      // out_ptr_r <= out_ptr;
      ptr_diff <= in_ptr - out_ptr;
      {locs_o, ptr_diff_r} <= {ptr_diff_r, ptr_diff};
      
      read_r <= read_i;
      empty_o <= ptr_diff_r == 0;
      full_o <= ptr_diff_r >= LENGTH-4; // a bit of overhead

      valid_r <= valid_i && !full_o;

      if (valid_r && !full_o) begin
	 fifo_mem[in_ptr] <= data_r;
	 in_ptr <= in_ptr + 1;
      end

      // TODO: pipeline the output memory so that there are always 3-4
      // samples ready to read out, and the memory only goes dry when
      // the FIFO goes empty! Must work cycle-to-cycle.
      
      // always read out memory
      out_data_r <= fifo_mem[out_ptr];
      data_o <= out_data_r;

      if (read_i) valid_o <= 0;
      if (!valid_o && !empty_o) valid_o <= 1;

      if (read_r && !empty_o) begin
	 out_ptr <= out_ptr + 1;
      end
   end

endmodule // flofifo
`endif //  `ifndef _FLOFIFO_
