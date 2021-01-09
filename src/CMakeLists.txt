# Verilator CMake for building a unified binary for simulating the
# Flocra server and Zynq PS/PL system.
#
# Mostly borrowed from the Verilator CMake example file.
#
# Use it as follows:
# cd /path/to/flocra
# rm -rf build && mkdir build && cd build
# cmake ../src
# make -j4
#
# This will build the flocra_sim binary.

cmake_minimum_required(VERSION 3.12)
project(flocra_sim)

find_package(verilator HINTS $ENV{VERILATOR_ROOT} ${VERILATOR_ROOT})
if (NOT verilator_FOUND)
  message(FATAL_ERROR "Verilator was not found. Either install it, or set the VERILATOR_ROOT environment variable")
endif()

set (CMAKE_C_FLAGS "-O3 -g -Wall -std=c11")
set (CMAKE_CXX_FLAGS "-O3 -g -Wall -std=c++17")

# # For debugging only
# set (CMAKE_C_FLAGS "-O0 -g -Wall -std=c11")
# set (CMAKE_CXX_FLAGS "-O0 -g -Wall -std=c++17")

set(SERVER_PATH "../../marcos_server/src")
set(SERVER_SRC	${SERVER_PATH}/hardware.cpp
		${SERVER_PATH}/iface.cpp
		${SERVER_PATH}/mpack/mpack.c)

add_compile_definitions(VERILATOR_BUILD)

add_executable(flocra_sim flocra_sim_main.cpp flocra_model.cpp ${SERVER_SRC})
target_include_directories(flocra_sim PRIVATE ${SERVER_PATH} "./")

# TODO Verilator CFLAGS

verilate(flocra_sim
	INCLUDE_DIRS "../hdl"
	VERILATOR_ARGS -Wall -Wno-UNUSED -Wno-PINCONNECTEMPTY -Wno-PINMISSING --cc -O3 --threads 4 --trace-fst --trace-depth 4
	SOURCES ../hdl/flocra_model.sv)
