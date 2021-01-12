#ifndef FLOCRA_MODEL_HPP
#define FLOCRA_MODEL_HPP

#include "verilated.h"
class Vflocra_model;
struct flocra_csv;
static const unsigned CSV_VERSION_MAJOR = 0, CSV_VERSION_MINOR = 1;

class flocra_model {
public:
	vluint64_t MAX_SIM_TIME;
	Vflocra_model *vfm;
	VerilatedFstC *tfp;
	flocra_csv *csv;
	bool _fst_output = false, _csv_output = false;

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
