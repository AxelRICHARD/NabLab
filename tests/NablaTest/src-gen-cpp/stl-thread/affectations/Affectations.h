/* DO NOT EDIT THIS FILE - it is machine generated */

#ifndef __AFFECTATIONS_H_
#define __AFFECTATIONS_H_

#include <fstream>
#include <iomanip>
#include <type_traits>
#include <limits>
#include <utility>
#include <cmath>
#include "nablalib/mesh/CartesianMesh2DFactory.h"
#include "nablalib/mesh/CartesianMesh2D.h"
#include "nablalib/utils/Utils.h"
#include "nablalib/utils/Timer.h"
#include "nablalib/types/Types.h"
#include "nablalib/utils/stl/Parallel.h"

using namespace nablalib::mesh;
using namespace nablalib::utils;
using namespace nablalib::types;
using namespace nablalib::utils::stl;

/******************** Module declaration ********************/

class Affectations
{
public:
	struct Options
	{
		double maxTime;
		int maxIter;
		double deltat;

		void jsonInit(const char* jsonContent);
	};

	Affectations(CartesianMesh2D* aMesh, Options& aOptions);
	~Affectations();

	void simulate();
	void computeE1() noexcept;
	void computeE2() noexcept;
	void initE() noexcept;
	void initTandU() noexcept;
	void updateT() noexcept;
	void updateU() noexcept;
	void initE2() noexcept;
	void setUpTimeLoopN() noexcept;
	void executeTimeLoopN() noexcept;
	void setUpTimeLoopK() noexcept;
	void executeTimeLoopK() noexcept;
	void tearDownTimeLoopK() noexcept;
	void updateE() noexcept;

private:
	// Mesh and mesh variables
	CartesianMesh2D* mesh;
	size_t nbNodes, nbCells, nbNodesOfCell;

	// User options
	Options& options;

	// Timers
	Timer globalTimer;
	Timer cpuTimer;
	Timer ioTimer;

public:
	// Global variables
	int n;
	int k;
	double t_n;
	double t_nplus1;
	double t_n0;
	RealArray1D<2> u_n;
	RealArray1D<2> u_nplus1;
	RealArray1D<2> u_n0;
	std::vector<RealArray1D<2>> X;
	std::vector<RealArray1D<2>> e1;
	std::vector<RealArray1D<2>> e2_n;
	std::vector<RealArray1D<2>> e2_nplus1;
	std::vector<RealArray1D<2>> e2_nplus1_k;
	std::vector<RealArray1D<2>> e2_nplus1_kplus1;
	std::vector<RealArray1D<2>> e2_nplus1_k0;
	std::vector<RealArray1D<2>> e_n;
	std::vector<RealArray1D<2>> e_nplus1;
	std::vector<RealArray1D<2>> e_n0;
};

#endif
