#include "flocra_model.hpp"

#include "Vflocra.h"
#include "verilated_vcd_c.h"

#include <iostream>

using namespace std;

vluint64_t main_time = 0;

flocra_model::flocra_model(int argc, char *argv[]) : MAX_TIME(50e6) {
	Verilated::commandArgs(argc, argv);
	vfm = new Vflocra;

	Verilated::traceEverOn(true);	
	tfp = new VerilatedVcdC;

	vfm->trace(tfp, 10);
	tfp->open("flocra_model.vcd");

	// Init
	vfm->s0_axi_aclk = 1;
	vfm->trig_i = 0;
	
	vfm->fhdo_sdi_i = 0;

	// AXI slave bus
	vfm->s0_axi_awaddr = 0;
	vfm->s0_axi_wdata = 0;
	vfm->s0_axi_araddr = 0;
	
	vfm->s0_axi_aresetn = 0;
	vfm->s0_axi_awprot = 0;
	vfm->s0_axi_awvalid = 0;
	vfm->s0_axi_wstrb = 0;
	vfm->s0_axi_wvalid = 0;
	vfm->s0_axi_bready = 0;
	vfm->s0_axi_arprot = 0;
	vfm->s0_axi_arvalid = 0;
	vfm->s0_axi_rready = 0;
	
	// AXI stream slaves
	vfm->rx0_axis_tvalid_i = 0;
	vfm->rx0_axis_tdata_i = 0;
	
	vfm->rx1_axis_tvalid_i = 0;
	vfm->rx1_axis_tdata_i = 0;
	
	// Wait 5 cycles
	for (int k = 0; k < 10; ++k) tick();

	// End reset, followed by 5 more cycles
	vfm->s0_axi_aresetn = 1;
	vfm->s0_axi_bready = 1;

	for (int k = 0; k < 10; ++k) tick();	
}

flocra_model::~flocra_model() {
	vfm->final();
	delete vfm;
	delete tfp;
}

int flocra_model::tick() {
	if (main_time < MAX_TIME) {
		// TODO: progress bar

		tfp->dump(main_time); // NOTE: time in ns assuming 100 MHz clock

		// update clock
		vfm->s0_axi_aclk = !vfm->s0_axi_aclk;
       
		vfm->eval();
		main_time += 5;

		return 0;
	} else return -1;
}

uint32_t flocra_model::rd32(uint32_t addr) {
	static const unsigned READ_TICKS_SLOW = 10000;

	tick();

	vfm->s0_axi_arvalid = 1;
	vfm->s0_axi_araddr = addr;

	// wait for address to be accepted
	unsigned read_ticks = 0;
	while (!vfm->s0_axi_arready) {
		tick();
		read_ticks++;
		if (read_ticks > READ_TICKS_SLOW) {
			cout << main_time << "ns: Slow to accept read address " << addr << endl;
			read_ticks = 0;
			break;
		}
	}

	read_ticks = 0;

	while (!vfm->s0_axi_rvalid) {
		tick();
		read_ticks++;
		if (read_ticks > READ_TICKS_SLOW) {
			cout << main_time << "ns: Slow to return data at address " << addr << endl;
			read_ticks = 0;
			break;
		}
	}
	tick();
	uint32_t data = vfm->s0_axi_rdata; // save data from bus

	vfm->s0_axi_arvalid = 0;
	vfm->s0_axi_rready = 1;
	tick(); tick(); // 1 full clock cycle
	vfm->s0_axi_rready = 0;
	
	return data;
}

void flocra_model::wr32(uint32_t addr, uint32_t data) {
	static const unsigned WRITE_TICKS_SLOW = 10000;

	tick();

	vfm->s0_axi_wdata = data;
	vfm->s0_axi_awaddr = addr;
	vfm->s0_axi_awvalid = 1;
	vfm->s0_axi_wvalid = 1;

	// wait for flocra to be ready
	unsigned write_ticks = 0;
	while (! (vfm->s0_axi_awready and vfm->s0_axi_wready) ) {
		tick();
		write_ticks++;
		if (write_ticks > WRITE_TICKS_SLOW) {
			cout << main_time << ": Slow to write to address " << addr << endl;
			write_ticks = 0;
			break;
		}
	}

	// end bus transaction
	tick();tick();
	vfm->s0_axi_awvalid = 0;
	vfm->s0_axi_wvalid = 0;

	tick();
}
