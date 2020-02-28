package fr.cea.nabla.ir.generator.java

import fr.cea.nabla.ir.ir.IntervalIterationBlock
import fr.cea.nabla.ir.ir.SpaceIterationBlock

import static extension fr.cea.nabla.ir.generator.IteratorExtensions.*
import static extension fr.cea.nabla.ir.generator.SizeTypeContentProvider.*
import static extension fr.cea.nabla.ir.generator.Utils.*
import static extension fr.cea.nabla.ir.generator.java.IndexBuilder.*

class IterationBlockExtensions
{
	static def dispatch getIndexName(SpaceIterationBlock it)
	{
		range.indexName
	}

	static def dispatch getIndexName(IntervalIterationBlock it)
	{
		index.name
	}

	static def dispatch defineInterval(SpaceIterationBlock it, CharSequence innerContent)
	{
		if (range.container.connectivity.indexEqualId)
			innerContent
		else
		'''
		{
			final int[] «range.containerName» = «range.accessor»;
			final int «nbElems» = «range.containerName».length;
			«innerContent»
		}
		'''
	}

	static def dispatch defineInterval(IntervalIterationBlock it, CharSequence innerContent)
	{
		innerContent
	}

	static def dispatch getNbElems(SpaceIterationBlock it)
	{
		if (range.container.connectivity.indexEqualId)
			range.container.connectivity.nbElems
		else
			'nbElems' + indexName.toFirstUpper
	}

	static def dispatch getNbElems(IntervalIterationBlock it)
	{
		nbElems.content
	}
}