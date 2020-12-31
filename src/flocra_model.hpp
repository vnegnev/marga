#ifndef FLOCRA_MODEL_HPP
#define FLOCRA_MODEL_HPP

#include "verilated.h"

class Vflocra;

class flocra_model {
public:
	const vluint64_t MAX_TIME;
	Vflocra *vfm;
	VerilatedVcdC *tfp;

	flocra_model(int argc, char *argv[]);
	~flocra_model();

	// If system's finished, return -1; otherwise 0
	int tick();

	// Reads and writes must be relative to flocra's memory space
	// (i.e. slave reg 0 has address 0x0, slave reg 1 has address
	// 0x4, etc
	uint32_t rd32(uint32_t flo_addr);
	void wr32(uint32_t flo_addr, uint32_t data);
};

#endif
