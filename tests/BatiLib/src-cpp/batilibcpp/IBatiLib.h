/*** GENERATED FILE - DO NOT OVERWRITE ***/

#ifndef __IBATILIB_H_
#define __IBATILIB_H_

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

using namespace nablalib::mesh;
using namespace nablalib::utils;
using namespace nablalib::types;

class IBatiLib
{
public:
	virtual void jsonInit(const char* jsonContent) = 0;

	/* 
	 * Here are the other methods to implement in Sequential class.
	 * Some of them can be templates. Therefore they can not be virtual.
	 *

	double nextWaveHeight();

	template<size_t x>
	double nextDepth1(double x0, RealArray1D<x> x1);

	template<size_t x, size_t y>
	double nextDepth2(double x0, RealArray2D<x,y> x1);

	template<size_t x>
	RealArray1D<x> nextDepth3(RealArray1D<x> x0);

	template<size_t x, size_t y>
	RealArray2D<x,y> nextDepth4(RealArray2D<x,y> x0);
	*/
};

#endif
