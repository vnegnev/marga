//-----------------------------------------------------------------------------
// Title         : flofifo_tb
// Project       : flocra
//-----------------------------------------------------------------------------
// File          : flofifo_tb.sv
// Author        :   <vlad@vlad-laptop>
// Created       : 25.12.2020
// Last modified : 25.12.2020
//-----------------------------------------------------------------------------
// Description :
// Testbench for flofifo: emulates various bursts and burst readouts
//-----------------------------------------------------------------------------
// Copyright (c) 2020 by OCRA developers This model is the confidential and
// proprietary property of OCRA developers and the possession or use of this
// file requires a written license from OCRA developers.
//------------------------------------------------------------------------------

`ifndef _FLOFIFO_TB_
 `define _FLOFIFO_TB_

 `include "flofifo.sv"

 `timescale 1ns/1ns

module flofifo_tb;
   parameter LENGTH = 32, WIDTH = 32;
   /*AUTOREGINPUT*/
   // Beginning of automatic reg inputs (for undeclared instantiated-module inputs)
   reg			clk;			// To UUT of flofifo.v
   reg [WIDTH-1:0]	data_i;			// To UUT of flofifo.v
   reg			read_i;			// To UUT of flofifo.v
   reg			valid_i;		// To UUT of flofifo.v
   // End of automatics
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [WIDTH-1:0]	data_o;			// From UUT of flofifo.v
   wire			empty_o;		// From UUT of flofifo.v
   wire			full_o;			// From UUT of flofifo.v
   wire [$clog2(LENGTH)-1:0] locs_o;		// From UUT of flofifo.v
   wire			valid_o;		// From UUT of flofifo.v
   // End of automatics

   reg err = 0;
   integer k;
   always #5 clk = !clk;

   initial begin
      $dumpfile("icarus_compile/000_flofifo_tb.lxt");
      $dumpvars(0, flofifo_tb);

      clk = 1;
      data_i = 0;
      read_i = 0;
      valid_i = 0;

      // Single write, single read
      #13 data_i = 1; valid_i = 1;
      #10 valid_i = 0;
      #70 read_i = 1;
      #10 read_i = 0;

      // Multiple continuous write, multiple continuous read once write is done
      #10 valid_i = 1;
      for (k = 0; k < 10; k = k + 1) begin
	 data_i <= 100 + k; #10;
      end
      valid_i = 0;
      #50 read_i = 1;
      #90 read_i = 0;

      // Fill up the FIFO
      #10 valid_i = 1;
      for (k = 0; k < LENGTH; k = k + 1) begin
	 data_i <= 200 + k; #10;
      end
      valid_i = 0;

      // TODO: CONTINUE HERE, ADD CHECKS ETC
      err = 1;

      #5000 if (err) begin
	 $display("THERE WERE ERRORS");
	 $stop; // to return a nonzero error code if the testbench is later scripted at a higher level
      end
      $finish;
   end

   flofifo #(/*AUTOINSTPARAM*/
	     // Parameters
	     .LENGTH			(LENGTH),
	     .WIDTH			(WIDTH))
   UUT(/*AUTOINST*/
       // Outputs
       .data_o				(data_o[WIDTH-1:0]),
       .valid_o				(valid_o),
       .locs_o				(locs_o[$clog2(LENGTH)-1:0]),
       .empty_o				(empty_o),
       .full_o				(full_o),
       // Inputs
       .clk				(clk),
       .data_i				(data_i[WIDTH-1:0]),
       .valid_i				(valid_i),
       .read_i				(read_i));

endmodule // flofifo_tb
`endif //  `ifndef _FLOFIFO_TB_

      
