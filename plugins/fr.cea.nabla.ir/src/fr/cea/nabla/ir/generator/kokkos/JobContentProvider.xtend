/*******************************************************************************
 * Copyright (c) 2018 CEA
 * This program and the accompanying materials are made available under the 
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * SPDX-License-Identifier: EPL-2.0
 * Contributors: see AUTHORS file
 *******************************************************************************/
package fr.cea.nabla.ir.generator.kokkos

import fr.cea.nabla.ir.ir.BaseType
import fr.cea.nabla.ir.ir.ConnectivityVariable
import fr.cea.nabla.ir.ir.InSituJob
import fr.cea.nabla.ir.ir.InstructionJob
import fr.cea.nabla.ir.ir.Job
import fr.cea.nabla.ir.ir.TimeLoopCopyJob
import fr.cea.nabla.ir.ir.TimeLoopJob
import org.eclipse.xtend.lib.annotations.Accessors

import static extension fr.cea.nabla.ir.ArgOrVarExtensions.*
import static extension fr.cea.nabla.ir.Utils.getIrModule
import static extension fr.cea.nabla.ir.generator.Utils.*
import static extension fr.cea.nabla.ir.generator.kokkos.ExpressionContentProvider.*

abstract class JobContentProvider 
{
	@Accessors val extension InstructionContentProvider instructionContentProvider

	new(InstructionContentProvider icp) 
	{ 
		instructionContentProvider = icp
	}

	abstract def CharSequence getJobCallsContent(Iterable<Job> jobs)
	abstract def CharSequence getContent(Job it)

	protected def dispatch CharSequence getInnerContent(InstructionJob it)
	'''
		«instruction.innerContent»
	'''

	protected def dispatch CharSequence getInnerContent(InSituJob it)
	'''
		if (!writer.isDisabled() && «periodVariable.name» >= «lastDumpVariable.name»)
		{
			std::map<string, double*> cellVariables;
			std::map<string, double*> nodeVariables;
			«FOR v : dumpedVariables.filter(ConnectivityVariable)»
			«v.type.connectivities.head.returnType.type.name»Variables.insert(pair<string,double*>("«v.persistenceName»", «v.name».data()));
			«ENDFOR»
			auto quads = mesh->getGeometricMesh()->getQuads();
			writer.writeFile(«iterationVariable.name», «irModule.timeVariable.name», «irModule.nodeCoordVariable.name».data(), nbCells, quads.data(), cellVariables, nodeVariables);
			«lastDumpVariable.name» += «periodVariable.name»;
		}
	'''

	protected def dispatch CharSequence getInnerContent(TimeLoopJob it)
	'''
		«timeLoop.counter.name» = 0;
		do
		{
			«timeLoop.counter.name»++;
			«FOR j : jobs.sortBy[at]»
				«j.codeName»(); // @«j.at»
			«ENDFOR»

			// Switch variables to prepare next iteration
		«FOR copy : copies»
			std::swap(«copy.source.name», «copy.destination.name»);
		«ENDFOR»
		} while («timeLoop.whileCondition.content»);
	'''

	protected def dispatch CharSequence getInnerContent(TimeLoopCopyJob it)
	'''
		«FOR copy : copies»
			«IF (copy.destination.type instanceof BaseType)»
			«copy(copy.destination.name, copy.source.name, (copy.destination.type as BaseType).sizes.size)»
			«ELSE»
			deep_copy(«copy.destination.name», «copy.source.name»);
			«ENDIF»
		«ENDFOR»
	'''

	private static def CharSequence copy(String left, String right, int dimension)
	{
		if (dimension == 0)
			'''«left» = «right»;'''
		else
		{
			val indexName = 'i' + dimension
			val suffix = '[' + indexName + ']'
			'''
				for (int «indexName»=0 ; «indexName»<«left».size() ; «indexName»++)
					«copy(left + suffix, right + suffix, dimension-1)»
			'''
		}
	}
}