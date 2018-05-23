package fr.cea.nabla.ir

import fr.cea.nabla.ir.ir.Function
import fr.cea.nabla.ir.ir.IrFactory
import fr.cea.nabla.ir.ir.IrModule
import fr.cea.nabla.ir.ir.Loop
import fr.cea.nabla.ir.ir.Reduction
import fr.cea.nabla.ir.ir.ReductionCall
import fr.cea.nabla.ir.ir.ReductionInstruction
import fr.cea.nabla.ir.ir.ScalarVarDefinition
import java.util.List
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.emf.ecore.util.FeatureMapUtil

class Ir2IrNoInternalReduction implements Ir2IrPass
{
	override getDescription() 
	{
		'Replacing internal reductions by loops'
	}

	/**
	 * Transforme le module m pour qu'il n'est plus de d'instance de ReductionInstruction.
	 * Les r�ductions sont remplac�es par des fonctions traditionnelles.
	 */
	override transform(IrModule m)
	{
		for (reductionInstr : m.eAllContents.filter(ReductionInstruction).toIterable)
		{
			// cr�ation des fonctions correspondantes
			// 2 arguments IN : 1 du type de la collection, l'autre du type de retour (appel en chaine)
			val reduc = reductionInstr.reduction.reduction
			val function = findOrCreateFunction(m, reduc)
										
			// transformation de la reduction
			val loop = reductionInstr.createReductionLoop(function)
			val variableDefinition = IrFactory::eINSTANCE.createScalarVarDefinition => [ variables += reductionInstr.variable ]
			replace(reductionInstr, variableDefinition, loop)			

			// si la r�duction n'est pas r�f�renc�e, on l'efface
			if (!m.eAllContents.filter(ReductionCall).exists[x | x.reduction == reduc])
				EcoreUtil::delete(reduc, true)
		}
	}
	
	private def findOrCreateFunction(IrModule m, Reduction r)
	{
		var function = m.functions.findFirst
		[   
			name == r.name && 
			inTypes.length == 2 && 
			inTypes.get(0) == r.collectionType && 
			inTypes.get(1) == r.returnType && 
			returnType == r.returnType
		]
		
		if (function === null) 
		{ 
			function = IrFactory::eINSTANCE.createFunction =>
			[
				name = r.name
				inTypes += r.collectionType
				inTypes += r.returnType
				returnType = r.returnType
			]
			m.functions += function
		}
		
		return function
	}
	
	/**
	 * Cr�ation de la boucle de la r�duction.
	 * L'it�rateur de la boucle est celui de la r�duction.
	 * La r�duction est transform�e en une fonction de m�me nom.
	 */
	private def createReductionLoop(ReductionInstruction reductionInstr, Function f)
	{
		val loop = IrFactory::eINSTANCE.createLoop
		loop.iterator = reductionInstr.reduction.iterator
		loop.body = IrFactory::eINSTANCE.createAffectation => 
		[
			left = IrFactory::eINSTANCE.createVarRef => [ variable = reductionInstr.variable ]
			operator = '='
			right = IrFactory::eINSTANCE.createFunctionCall =>
			[
				function = f
				args += IrFactory::eINSTANCE.createVarRef => [ variable = reductionInstr.variable ]
				args += reductionInstr.reduction.arg
			]
		]
		return loop
	}
	
	/**
	 * Extension de la m�thode EcoreUtil::replace pour une liste d'objet.
	 * Si le eContainmentFeature est de cardinalit� 1, un block est cr��,
	 * sinon les instructions sont ajout�es une � une � l'emplacement de la r�duction.
	 */
	private def replace(ReductionInstruction reduction, ScalarVarDefinition replacementI1, Loop replacementI2)
	{
    	val container = reduction.eContainer
    	if (container !== null)
		{
			val feature = reduction.eContainmentFeature
			if (FeatureMapUtil.isMany(container, feature))
			{
				val list = container.eGet(feature) as List<Object>
				val reductionIndex = list.indexOf(reduction)
				list.set(reductionIndex, replacementI1)
				list.add(reductionIndex+1, replacementI2)
      		}
			else
			{
				val replacementBlock = IrFactory::eINSTANCE.createInstructionBlock => 
				[ 
					instructions += replacementI1
					instructions += replacementI2
				]
				container.eSet(feature, replacementBlock)
			}
		}
	}
}