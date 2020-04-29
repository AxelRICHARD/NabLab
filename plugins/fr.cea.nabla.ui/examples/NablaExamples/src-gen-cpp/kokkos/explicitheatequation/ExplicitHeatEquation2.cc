#include <iostream>
#include <iomanip>
#include <type_traits>
#include <limits>
#include <utility>
#include <cmath>
#include <Kokkos_Core.hpp>
#include <Kokkos_hwloc.hpp>

#include <rapidjson/document.h>
#include <rapidjson/istreamwrapper.h>

#include "mesh/CartesianMesh2DGenerator.h"
#include "mesh/CartesianMesh2D.h"
#include "mesh/PvdFileWriter2D.h"
#include "utils/Utils.h"
#include "utils/Timer.h"
#include "types/Types.h"
#include "types/MathFunctions.h"
#include "utils/kokkos/Parallel.h"

using namespace nablalib;


template<size_t x>
KOKKOS_INLINE_FUNCTION
RealArray1D<x> sumR1(RealArray1D<x> a, RealArray1D<x> b)
{
	return a + b;
}

KOKKOS_INLINE_FUNCTION
double minR0(double a, double b)
{
	return MathFunctions::min(a, b);
}

KOKKOS_INLINE_FUNCTION
double sumR0(double a, double b)
{
	return a + b;
}

KOKKOS_INLINE_FUNCTION
double prodR0(double a, double b)
{
	return a * b;
}

class ExplicitHeatEquation
{
public:
	struct Options
	{
		// Should be const but usefull to set them from main args
		double X_LENGTH;
		double Y_LENGTH;
		double u0;
		RealArray1D<2> vectOne;
		size_t X_EDGE_ELEMS;
		size_t Y_EDGE_ELEMS;
		double X_EDGE_LENGTH = 0.05;
		double Y_EDGE_LENGTH = 0.05;
		double option_stoptime = 1.0;
		size_t option_max_iterations = 500000000;

		Options(const std::string& fileName)
		{
			ifstream ifs(fileName);
			rapidjson::IStreamWrapper isw(ifs);
			rapidjson::Document d;
			d.ParseStream(isw);
			assert(d.IsObject());
			// X_LENGTH
			assert(d.HasMember("X_LENGTH"));
			const rapidjson::Value& valueof_X_LENGTH = d["X_LENGTH"];
			assert(valueof_X_LENGTH.IsDouble());
			X_LENGTH = valueof_X_LENGTH.GetDouble();
			// Y_LENGTH
			assert(d.HasMember("Y_LENGTH"));
			const rapidjson::Value& valueof_Y_LENGTH = d["Y_LENGTH"];
			assert(valueof_Y_LENGTH.IsDouble());
			X_LENGTH = valueof_Y_LENGTH.GetDouble();
			// u0
			assert(d.HasMember("u0"));
			const rapidjson::Value& valueof_u0 = d["u0"];
			assert(valueof_u0.IsDouble());
			X_LENGTH = valueof_u0.GetDouble();
			// vectOne
			assert(d.HasMember("vectOne"));
			const rapidjson::Value& valueof_vectOne = d["vectOne"];
			assert(valueof_vectOne.IsArray());
			assert(valueof_vectOne.Size() == 2);
			for (size_t i=0 ; i<2 ; i++)
			{
				assert(valueof_vectOne[i].IsDouble());
				vectOne[i] = valueof_vectOne[i].GetDouble();
			}
			// X_EDGE_ELEMS
			assert(d.HasMember("X_EDGE_ELEMS"));
			const rapidjson::Value& valueof_X_EDGE_ELEMS = d["X_EDGE_ELEMS"];
			assert(valueof_X_EDGE_ELEMS.IsInt());
			X_EDGE_ELEMS = valueof_X_EDGE_ELEMS.GetInt();
			// Y_EDGE_ELEMS
			assert(d.HasMember("Y_EDGE_ELEMS"));
			const rapidjson::Value& valueof_Y_EDGE_ELEMS = d["Y_EDGE_ELEMS"];
			assert(valueof_Y_EDGE_ELEMS.IsInt());
			Y_EDGE_ELEMS = valueof_Y_EDGE_ELEMS.GetInt();
		}
	};

	Options* options;

private:
	CartesianMesh2D* mesh;
	PvdFileWriter2D writer;
	size_t nbNodes, nbCells, nbFaces, nbNodesOfCell, nbNodesOfFace, nbCellsOfFace, nbNeighbourCells;
	int n;
	double t_n;
	double t_nplus1;
	double deltat;
	Kokkos::View<RealArray1D<2>*> X;
	Kokkos::View<RealArray1D<2>*> Xc;
	Kokkos::View<double*> xc;
	Kokkos::View<double*> yc;
	Kokkos::View<double*> u_n;
	Kokkos::View<double*> u_nplus1;
	Kokkos::View<double*> V;
	Kokkos::View<double*> D;
	Kokkos::View<double*> faceLength;
	Kokkos::View<double*> faceConductivity;
	Kokkos::View<double**> alpha;
	int lastDump;
	utils::Timer globalTimer;
	utils::Timer cpuTimer;
	utils::Timer ioTimer;

public:
	ExplicitHeatEquation(Options* aOptions, CartesianMesh2D* aCartesianMesh2D, string output)
	: options(aOptions)
	, mesh(aCartesianMesh2D)
	, writer("ExplicitHeatEquation", output)
	, nbNodes(mesh->getNbNodes())
	, nbCells(mesh->getNbCells())
	, nbFaces(mesh->getNbFaces())
	, nbNodesOfCell(CartesianMesh2D::MaxNbNodesOfCell)
	, nbNodesOfFace(CartesianMesh2D::MaxNbNodesOfFace)
	, nbCellsOfFace(CartesianMesh2D::MaxNbCellsOfFace)
	, nbNeighbourCells(CartesianMesh2D::MaxNbNeighbourCells)
	, t_n(0.0)
	, t_nplus1(0.0)
	, deltat(0.001)
	, X("X", nbNodes)
	, Xc("Xc", nbCells)
	, xc("xc", nbCells)
	, yc("yc", nbCells)
	, u_n("u_n", nbCells)
	, u_nplus1("u_nplus1", nbCells)
	, V("V", nbCells)
	, D("D", nbCells)
	, faceLength("faceLength", nbFaces)
	, faceConductivity("faceConductivity", nbFaces)
	, alpha("alpha", nbCells, nbCells)
	, lastDump(numeric_limits<int>::min())
	{
		// Copy node coordinates
		const auto& gNodes = mesh->getGeometry()->getNodes();
		for (size_t rNodes=0; rNodes<nbNodes; rNodes++)
			X(rNodes) = gNodes[rNodes];
	}

private:
	/**
	 * Job ComputeFaceLength called @1.0 in simulate method.
	 * In variables: X
	 * Out variables: faceLength
	 */
	KOKKOS_INLINE_FUNCTION
	void computeFaceLength() noexcept
	{
		Kokkos::parallel_for(nbFaces, KOKKOS_LAMBDA(const size_t& fFaces)
		{
			const Id fId(fFaces);
			double reduction3(0.0);
			{
				const auto nodesOfFaceF(mesh->getNodesOfFace(fId));
				const size_t nbNodesOfFaceF(nodesOfFaceF.size());
				for (size_t pNodesOfFaceF=0; pNodesOfFaceF<nbNodesOfFaceF; pNodesOfFaceF++)
				{
					const Id pId(nodesOfFaceF[pNodesOfFaceF]);
					const Id pPlus1Id(nodesOfFaceF[(pNodesOfFaceF+1+nbNodesOfFace)%nbNodesOfFace]);
					const size_t pNodes(pId);
					const size_t pPlus1Nodes(pPlus1Id);
					reduction3 = sumR0(reduction3, MathFunctions::norm(X(pNodes) - X(pPlus1Nodes)));
				}
			}
			faceLength(fFaces) = 0.5 * reduction3;
		});
	}
	
	/**
	 * Job ComputeTn called @1.0 in executeTimeLoopN method.
	 * In variables: deltat, t_n
	 * Out variables: t_nplus1
	 */
	KOKKOS_INLINE_FUNCTION
	void computeTn() noexcept
	{
		t_nplus1 = t_n + deltat;
	}
	
	/**
	 * Job ComputeV called @1.0 in simulate method.
	 * In variables: X
	 * Out variables: V
	 */
	KOKKOS_INLINE_FUNCTION
	void computeV() noexcept
	{
		Kokkos::parallel_for(nbCells, KOKKOS_LAMBDA(const size_t& jCells)
		{
			const Id jId(jCells);
			double reduction2(0.0);
			{
				const auto nodesOfCellJ(mesh->getNodesOfCell(jId));
				const size_t nbNodesOfCellJ(nodesOfCellJ.size());
				for (size_t pNodesOfCellJ=0; pNodesOfCellJ<nbNodesOfCellJ; pNodesOfCellJ++)
				{
					const Id pId(nodesOfCellJ[pNodesOfCellJ]);
					const Id pPlus1Id(nodesOfCellJ[(pNodesOfCellJ+1+nbNodesOfCell)%nbNodesOfCell]);
					const size_t pNodes(pId);
					const size_t pPlus1Nodes(pPlus1Id);
					reduction2 = sumR0(reduction2, MathFunctions::det(X(pNodes), X(pPlus1Nodes)));
				}
			}
			V(jCells) = 0.5 * reduction2;
		});
	}
	
	/**
	 * Job InitD called @1.0 in simulate method.
	 * In variables: 
	 * Out variables: D
	 */
	KOKKOS_INLINE_FUNCTION
	void initD() noexcept
	{
		Kokkos::parallel_for(nbCells, KOKKOS_LAMBDA(const size_t& cCells)
		{
			D(cCells) = 1.0;
		});
	}
	
	/**
	 * Job InitXc called @1.0 in simulate method.
	 * In variables: X
	 * Out variables: Xc
	 */
	KOKKOS_INLINE_FUNCTION
	void initXc() noexcept
	{
		Kokkos::parallel_for(nbCells, KOKKOS_LAMBDA(const size_t& cCells)
		{
			const Id cId(cCells);
			RealArray1D<2> reduction0({0.0, 0.0});
			{
				const auto nodesOfCellC(mesh->getNodesOfCell(cId));
				const size_t nbNodesOfCellC(nodesOfCellC.size());
				for (size_t pNodesOfCellC=0; pNodesOfCellC<nbNodesOfCellC; pNodesOfCellC++)
				{
					const Id pId(nodesOfCellC[pNodesOfCellC]);
					const size_t pNodes(pId);
					reduction0 = sumR1(reduction0, X(pNodes));
				}
			}
			Xc(cCells) = 0.25 * reduction0;
		});
	}
	
	/**
	 * Job UpdateU called @1.0 in executeTimeLoopN method.
	 * In variables: alpha, u_n
	 * Out variables: u_nplus1
	 */
	KOKKOS_INLINE_FUNCTION
	void updateU() noexcept
	{
		Kokkos::parallel_for(nbCells, KOKKOS_LAMBDA(const size_t& cCells)
		{
			const Id cId(cCells);
			double reduction6(0.0);
			{
				const auto neighbourCellsC(mesh->getNeighbourCells(cId));
				const size_t nbNeighbourCellsC(neighbourCellsC.size());
				for (size_t dNeighbourCellsC=0; dNeighbourCellsC<nbNeighbourCellsC; dNeighbourCellsC++)
				{
					const Id dId(neighbourCellsC[dNeighbourCellsC]);
					const size_t dCells(dId);
					reduction6 = sumR0(reduction6, alpha(cCells,dCells) * u_n(dCells));
				}
			}
			u_nplus1(cCells) = alpha(cCells,cCells) * u_n(cCells) + reduction6;
		});
	}
	
	/**
	 * Job ComputeFaceConductivity called @2.0 in simulate method.
	 * In variables: D
	 * Out variables: faceConductivity
	 */
	KOKKOS_INLINE_FUNCTION
	void computeFaceConductivity() noexcept
	{
		Kokkos::parallel_for(nbFaces, KOKKOS_LAMBDA(const size_t& fFaces)
		{
			const Id fId(fFaces);
			double reduction4(1.0);
			{
				const auto cellsOfFaceF(mesh->getCellsOfFace(fId));
				const size_t nbCellsOfFaceF(cellsOfFaceF.size());
				for (size_t c1CellsOfFaceF=0; c1CellsOfFaceF<nbCellsOfFaceF; c1CellsOfFaceF++)
				{
					const Id c1Id(cellsOfFaceF[c1CellsOfFaceF]);
					const size_t c1Cells(c1Id);
					reduction4 = prodR0(reduction4, D(c1Cells));
				}
			}
			double reduction5(0.0);
			{
				const auto cellsOfFaceF(mesh->getCellsOfFace(fId));
				const size_t nbCellsOfFaceF(cellsOfFaceF.size());
				for (size_t c2CellsOfFaceF=0; c2CellsOfFaceF<nbCellsOfFaceF; c2CellsOfFaceF++)
				{
					const Id c2Id(cellsOfFaceF[c2CellsOfFaceF]);
					const size_t c2Cells(c2Id);
					reduction5 = sumR0(reduction5, D(c2Cells));
				}
			}
			faceConductivity(fFaces) = 2.0 * reduction4 / reduction5;
		});
	}
	
	/**
	 * Job InitU called @2.0 in simulate method.
	 * In variables: Xc, u0, vectOne
	 * Out variables: u_n
	 */
	KOKKOS_INLINE_FUNCTION
	void initU() noexcept
	{
		Kokkos::parallel_for(nbCells, KOKKOS_LAMBDA(const size_t& cCells)
		{
			if (MathFunctions::norm(Xc(cCells) - options->vectOne) < 0.5) 
				u_n(cCells) = options->u0;
			else
				u_n(cCells) = 0.0;
		});
	}
	
	/**
	 * Job InitXcAndYc called @2.0 in simulate method.
	 * In variables: Xc
	 * Out variables: xc, yc
	 */
	KOKKOS_INLINE_FUNCTION
	void initXcAndYc() noexcept
	{
		Kokkos::parallel_for(nbCells, KOKKOS_LAMBDA(const size_t& cCells)
		{
			xc(cCells) = Xc(cCells)[0];
			yc(cCells) = Xc(cCells)[1];
		});
	}
	
	/**
	 * Job computeDeltaTn called @2.0 in simulate method.
	 * In variables: D, X_EDGE_LENGTH, Y_EDGE_LENGTH
	 * Out variables: deltat
	 */
	KOKKOS_INLINE_FUNCTION
	void computeDeltaTn() noexcept
	{
		double reduction1;
		Kokkos::parallel_reduce(nbCells, KOKKOS_LAMBDA(const size_t& cCells, double& accu)
		{
			accu = minR0(accu, options->X_EDGE_LENGTH * options->Y_EDGE_LENGTH / D(cCells));
		}, KokkosJoiner<double>(reduction1, numeric_limits<double>::max(), &minR0));
		deltat = reduction1 * 0.24;
	}
	
	/**
	 * Job computeAlphaCoeff called @3.0 in simulate method.
	 * In variables: V, Xc, deltat, faceConductivity, faceLength
	 * Out variables: alpha
	 */
	KOKKOS_INLINE_FUNCTION
	void computeAlphaCoeff() noexcept
	{
		Kokkos::parallel_for(nbCells, KOKKOS_LAMBDA(const size_t& cCells)
		{
			const Id cId(cCells);
			double alphaDiag(0.0);
			{
				const auto neighbourCellsC(mesh->getNeighbourCells(cId));
				const size_t nbNeighbourCellsC(neighbourCellsC.size());
				for (size_t dNeighbourCellsC=0; dNeighbourCellsC<nbNeighbourCellsC; dNeighbourCellsC++)
				{
					const Id dId(neighbourCellsC[dNeighbourCellsC]);
					const size_t dCells(dId);
					const Id fId(mesh->getCommonFace(cId, dId));
					const size_t fFaces(fId);
					const double alphaExtraDiag(deltat / V(cCells) * (faceLength(fFaces) * faceConductivity(fFaces)) / MathFunctions::norm(Xc(cCells) - Xc(dCells)));
					alpha(cCells,dCells) = alphaExtraDiag;
					alphaDiag = alphaDiag + alphaExtraDiag;
				}
			}
			alpha(cCells,cCells) = 1 - alphaDiag;
		});
	}
	
	/**
	 * Job ExecuteTimeLoopN called @4.0 in simulate method.
	 * In variables: alpha, deltat, t_n, u_n
	 * Out variables: t_nplus1, u_nplus1
	 */
	KOKKOS_INLINE_FUNCTION
	void executeTimeLoopN() noexcept
	{
		n = 0;
		bool continueLoop = true;
		do
		{
			globalTimer.start();
			cpuTimer.start();
			n++;
			dumpVariables(n);
			if (n!=1)
				std::cout << "[" << __CYAN__ << __BOLD__ << setw(3) << n << __RESET__ "] t = " << __BOLD__
					<< setiosflags(std::ios::scientific) << setprecision(8) << setw(16) << t_n << __RESET__;
		
			computeTn(); // @1.0
			updateU(); // @1.0
			
		
			// Evaluate loop condition with variables at time n
			continueLoop = (t_nplus1 < options->option_stoptime && n + 1 < options->option_max_iterations);
		
			if (continueLoop)
			{
				// Switch variables to prepare next iteration
				std::swap(t_nplus1, t_n);
				std::swap(u_nplus1, u_n);
			}
		
			cpuTimer.stop();
			globalTimer.stop();
		
			// Timers display
			if (!writer.isDisabled())
				std::cout << " {CPU: " << __BLUE__ << cpuTimer.print(true) << __RESET__ ", IO: " << __BLUE__ << ioTimer.print(true) << __RESET__ "} ";
			else
				std::cout << " {CPU: " << __BLUE__ << cpuTimer.print(true) << __RESET__ ", IO: " << __RED__ << "none" << __RESET__ << "} ";
			
			// Progress
			std::cout << utils::progress_bar(n, options->option_max_iterations, t_n, options->option_stoptime, 25);
			std::cout << __BOLD__ << __CYAN__ << utils::Timer::print(
				utils::eta(n, options->option_max_iterations, t_n, options->option_stoptime, deltat, globalTimer), true)
				<< __RESET__ << "\r";
			std::cout.flush();
		
			cpuTimer.reset();
			ioTimer.reset();
		} while (continueLoop);
	}

	void dumpVariables(int iteration)
	{
		if (!writer.isDisabled() && n >= lastDump + 1.0)
		{
			cpuTimer.stop();
			ioTimer.start();
			std::map<string, double*> cellVariables;
			std::map<string, double*> nodeVariables;
			cellVariables.insert(pair<string,double*>("Temperature", u_n.data()));
			auto quads = mesh->getGeometry()->getQuads();
			writer.writeFile(iteration, t_n, nbNodes, X.data(), nbCells, quads.data(), cellVariables, nodeVariables);
			lastDump = n;
			ioTimer.stop();
			cpuTimer.start();
		}
	}

public:
	void simulate()
	{
		std::cout << "\n" << __BLUE_BKG__ << __YELLOW__ << __BOLD__ <<"\tStarting ExplicitHeatEquation ..." << __RESET__ << "\n\n";
		
		std::cout << "[" << __GREEN__ << "MESH" << __RESET__ << "]      X=" << __BOLD__ << options->X_EDGE_ELEMS << __RESET__ << ", Y=" << __BOLD__ << options->Y_EDGE_ELEMS
			<< __RESET__ << ", X length=" << __BOLD__ << options->X_EDGE_LENGTH << __RESET__ << ", Y length=" << __BOLD__ << options->Y_EDGE_LENGTH << __RESET__ << std::endl;
		
		if (Kokkos::hwloc::available())
		{
			std::cout << "[" << __GREEN__ << "TOPOLOGY" << __RESET__ << "]  NUMA=" << __BOLD__ << Kokkos::hwloc::get_available_numa_count()
				<< __RESET__ << ", Cores/NUMA=" << __BOLD__ << Kokkos::hwloc::get_available_cores_per_numa()
				<< __RESET__ << ", Threads/Core=" << __BOLD__ << Kokkos::hwloc::get_available_threads_per_core() << __RESET__ << std::endl;
		}
		else
		{
			std::cout << "[" << __GREEN__ << "TOPOLOGY" << __RESET__ << "]  HWLOC unavailable cannot get topological informations" << std::endl;
		}
		
		// std::cout << "[" << __GREEN__ << "KOKKOS" << __RESET__ << "]    " << __BOLD__ << (is_same<MyLayout,Kokkos::LayoutLeft>::value?"Left":"Right")" << __RESET__ << " layout" << std::endl;
		
		if (!writer.isDisabled())
			std::cout << "[" << __GREEN__ << "OUTPUT" << __RESET__ << "]    VTK files stored in " << __BOLD__ << writer.outputDirectory() << __RESET__ << " directory" << std::endl;
		else
			std::cout << "[" << __GREEN__ << "OUTPUT" << __RESET__ << "]    " << __BOLD__ << "Disabled" << __RESET__ << std::endl;

		computeFaceLength(); // @1.0
		computeV(); // @1.0
		initD(); // @1.0
		initXc(); // @1.0
		computeFaceConductivity(); // @2.0
		initU(); // @2.0
		initXcAndYc(); // @2.0
		computeDeltaTn(); // @2.0
		computeAlphaCoeff(); // @3.0
		executeTimeLoopN(); // @4.0
		
		std::cout << __YELLOW__ << "\n\tDone ! Took " << __MAGENTA__ << __BOLD__ << globalTimer.print() << __RESET__ << std::endl;
	}
};

int main(int argc, char* argv[]) 
{
	Kokkos::initialize(argc, argv);
	ExplicitHeatEquation::Options* o = nullptr;
	string dataFile, output;

	if (argc == 2)
	{
		dataFile = argv[1];
		o = new ExplicitHeatEquation::Options(dataFile);
	}
	else if (argc == 6)
	{
		dataFile = argv[1];
		o = new ExplicitHeatEquation::Options(dataFile);
		o->X_EDGE_ELEMS = std::atoi(argv[2]);
		o->Y_EDGE_ELEMS = std::atoi(argv[3]);
		o->X_EDGE_LENGTH = std::atof(argv[4]);
		o->Y_EDGE_LENGTH = std::atof(argv[5]);
	}
	else if (argc == 7)
	{
		dataFile = argv[1];
		o = new ExplicitHeatEquation::Options(dataFile);
		o->X_EDGE_ELEMS = std::atoi(argv[2]);
		o->Y_EDGE_ELEMS = std::atoi(argv[3]);
		o->X_EDGE_LENGTH = std::atof(argv[4]);
		o->Y_EDGE_LENGTH = std::atof(argv[5]);
		output = argv[5];
	}
	else
	{
		std::cerr << "[ERROR] Wrong number of arguments. Expecting 1, 5 or 6 args: dataFile [X Y Xlength Ylength [output]]." << std::endl;
		std::cerr << "(ExplicitHeatEquationDefaultOptions.json, X=100, Y=10, Xlength=0.01, Ylength=0.01 output=current directory with no args)" << std::endl;
		return -1;
	}
	auto nm = CartesianMesh2DGenerator::generate(o->X_EDGE_ELEMS, o->Y_EDGE_ELEMS, o->X_EDGE_LENGTH, o->Y_EDGE_LENGTH);
	auto c = new ExplicitHeatEquation(o, nm, output);
	c->simulate();
	delete c;
	delete nm;
	delete o;
	Kokkos::finalize();
	return 0;
}