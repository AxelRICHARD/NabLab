/*******************************************************************************
 * Copyright (c) 2018 CEA
 * This program and the accompanying materials are made available under the 
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * SPDX-License-Identifier: EPL-2.0
 * Contributors: see AUTHORS file
 *******************************************************************************/
package fr.cea.nabla.ir.transformers

import fr.cea.nabla.ir.ir.AfterTimeLoopJob
import fr.cea.nabla.ir.ir.BeforeTimeLoopJob
import fr.cea.nabla.ir.ir.IrFactory
import fr.cea.nabla.ir.ir.IrModule
import fr.cea.nabla.ir.ir.Job
import fr.cea.nabla.ir.ir.NextTimeLoopIterationJob
import fr.cea.nabla.ir.ir.TimeLoopJob
import java.util.ArrayList
import org.jgrapht.alg.cycle.CycleDetector
import org.jgrapht.alg.shortestpath.FloydWarshallShortestPaths
import org.jgrapht.graph.DefaultWeightedEdge
import org.jgrapht.graph.DirectedWeightedPseudograph

import static extension fr.cea.nabla.ir.JobExtensions.*

class FillJobHLTs implements IrTransformationStep
{
	static val SourceNodeLabel = 'SourceNode'
	val outputTraces = new ArrayList<String>

	override getDescription() 
	{
		'Compute Hierarchical Logical Time (HLT) of each jobs'
	}

	/**
	 * Set the '@ attribute of every jobs of IrModule.
	 * The jgrapht library is used to compute the longest path to each node.
	 * Return false if the graph contains cycle (computing 'at' values is then impossible), true otherwise.
	 * If the graph contains cycles, nodes on cycle have their 'onCyle' attribute set to true.
	 */
	override transform(IrModule m)
	{
		if (m.jobs.empty) return true

		// check that IrModule has no job cycles (except timestep cycles)
		if (m.hasCycles) return false

		// No cyles => create subgraphs (i.e. JobContainer instances) corresponding to time loops
		m.distributeJobsInTimeLoops

		// compute at for each subGraph
		val subGraphs = m.jobs.groupBy[timeLoopContainer]
		for (subGraph : subGraphs.values)
			subGraph.fillAt

		return true
	}

	override getOutputTraces() 
	{
		outputTraces
	}

//	private def print(DirectedWeightedPseudograph<Job, DefaultWeightedEdge> g)
//	{
//		println('Graph nodes : ')
//		g.vertexSet.forEach[x|println('  ' + x.name)]
//		println('Graph arcs : ')
//		g.edgeSet.forEach[x|println('  ' + g.getEdgeSource(x).name + ' -> ' + g.getEdgeTarget(x).name)]
//	}

	/** Build the jgrapht graph corresponding to IrModule and check if it has cycles */
	private def hasCycles(IrModule it)
	{
		val g = createGraph(jobs.reject(TimeLoopJob))

		val cycles = g.findCycle
		val hasCycles = (cycles !== null)
		if (hasCycles)
		{
			outputTraces += '*** HLT impossible calculation: graph contains cycles.'
			outputTraces += '*** ' + cycles.map[name].join(' -> ')
		}

		return hasCycles
	}

	/** Return a graph created from the list of nodes */
	private def createGraph(Iterable<Job> jobs)
	{
		// Create nodes 
		val g = new DirectedWeightedPseudograph<Job, DefaultWeightedEdge>(DefaultWeightedEdge)
		jobs.forEach[x | g.addVertex(x)]

		// Create edges: no outgoing edges from NextTimeLoopIterationJob instances to break time cycles.
		for (from : jobs.reject(NextTimeLoopIterationJob))
			for (to : from.nextJobs)
				g.addEdge(from, to)

		// Add a source node and edges to nodes with no incoming edges
		val sourceNode = IrFactory::eINSTANCE.createInstructionJob => [ name = SourceNodeLabel ]
		g.addVertex(sourceNode)
		for (startNode : g.vertexSet.filter[v | v !== sourceNode && g.incomingEdgesOf(v).empty])
			g.addEdge(sourceNode, startNode)

		// display graph
		// g.print
		return g
	}

	/** Return the nodes list implied in at least one cycle. Return null if no cycle */
	private def findCycle(DirectedWeightedPseudograph<Job, DefaultWeightedEdge> g)
	{
		val cycleDetector = new CycleDetector<Job, DefaultWeightedEdge>(g)
		if (cycleDetector.detectCycles) 
		{
			val nodesOnCycle = cycleDetector.findCycles
			nodesOnCycle.forEach[onCycle = true]
			return nodesOnCycle
		}
		else return null
	}

	/** 
	 * Create JobContainer instances corresponding to time loops.
	 * Before this method, jobs are contained in a unique container hold by the module.
	 * After, there is one container by time loop and one main container and jobs are 
	 * splitted into the right containers.
	 * Warning: the module must not contain job cycles (must be checked before).
	 */
	private def void distributeJobsInTimeLoops(IrModule it)
	{
		val topLevelBeforeTLJobs = jobs.filter(BeforeTimeLoopJob).filter[timeLoopContainer === null]
		for (topLevelBeforeTJJob : topLevelBeforeTLJobs)
			for (next : topLevelBeforeTJJob.nextJobs.reject(TimeLoopJob))
				distributeJobsInTimeLoops(topLevelBeforeTJJob.associatedTimeLoop, next)
	}

	private def void distributeJobsInTimeLoops(TimeLoopJob tlj, Job j)
	{
		val nextJobs = j.nextJobs.reject(TimeLoopJob)
		switch j
		{
			BeforeTimeLoopJob: 
				nextJobs.forEach[x | distributeJobsInTimeLoops(j.associatedTimeLoop, x)]
			AfterTimeLoopJob: 
				if (tlj.outerTimeLoop !== null)
					nextJobs.forEach[x | distributeJobsInTimeLoops(tlj.outerTimeLoop, x)]
			NextTimeLoopIterationJob: 
				nextJobs.forEach[x | distributeJobsInTimeLoops(tlj, x)]
			default:
			{
				tlj.jobs += j
				nextJobs.forEach[x | distributeJobsInTimeLoops(tlj, x)]
			}
		}
	}

	/*
	 * Compute 'at' values of time loop nodes starting from sourceNode.
	 * We need the longest path to each node. The jgrapht algorithm computes the shortest path.
	 * To get the longest path, edges weight is set to -1.
	 */
	private def void fillAt(Iterable<Job> jobs)
	{
		val g = createGraph(jobs)
		val jalgo = new FloydWarshallShortestPaths<Job, DefaultWeightedEdge>(g)	

		var maxAtValue = 0.0
		g.edgeSet.forEach[e | g.setEdgeWeight(e, -1)]
		val sourceNode = g.vertexSet.findFirst[x | x.name == SourceNodeLabel]
		for (v : g.vertexSet.filter[v | v != sourceNode])
		{
			val graphPath = jalgo.getPath(sourceNode, v)
			if (graphPath!==null) 
			{
				val atValue = Math::abs(graphPath.weight)
				graphPath.endVertex.at = atValue
				if (atValue > maxAtValue) maxAtValue = atValue
			}
		}
	}
}
