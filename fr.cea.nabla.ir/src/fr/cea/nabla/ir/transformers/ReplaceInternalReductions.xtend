package fr.cea.nabla.ir.transformers

import fr.cea.nabla.ir.ir.BasicType
import fr.cea.nabla.ir.ir.Expression
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

class ReplaceInternalReductions extends ReplaceReductionsBase implements IrTransformationStep
{
	static val Operators = #{ 'sum'->'+', 'prod'->'*' }
	
	override getDescription() 
	{
		'Replace internal reductions by loops'
	}

	/**
	 * Transforme le module m pour qu'il n'est plus d'instance de ReductionInstruction.
	 * Les r�ductions sont remplac�es par des op�rateurs ou des fonctions traditionnelles.
	 * Le choix se fait en fonction de la liste Operators.
	 */
	override transform(IrModule m)
	{
		for (reductionInstr : m.eAllContents.filter(ReductionInstruction).filter[!reduction.external].toIterable)
		{
			// cr�ation des fonctions correspondantes
			// 2 arguments IN : 1 du type de la collection, l'autre du type de retour (appel en chaine)
			val reduc = reductionInstr.reduction.reduction
						
			// transformation de la reduction
			val loopExpression = createAffectationRHS(m, reductionInstr)
			val loop = createReductionLoop(reductionInstr.reduction.iterator, reductionInstr.variable, loopExpression, '=')
			val variableDefinition = IrFactory::eINSTANCE.createScalarVarDefinition => [ variables += reductionInstr.variable ]
			replace(reductionInstr, variableDefinition, loop)			

			// si la r�duction n'est pas r�f�renc�e, on l'efface
			if (!m.eAllContents.filter(ReductionCall).exists[x | x.reduction == reduc])
				EcoreUtil::delete(reduc, true)
		}
		return true
	}
	
	private def Expression createAffectationRHS(IrModule m, ReductionInstruction reductionInstr)
	{
		val reduction = reductionInstr.reduction.reduction
		val varRef = IrFactory::eINSTANCE.createVarRef => 
		[ 
			variable = reductionInstr.variable
			type = createExpressionType(variable.type)
		]
		
		if (Operators.keySet.contains(reduction.name))
		{
			return IrFactory::eINSTANCE.createBinaryExpression =>
			[
				type = createExpressionType(reduction.returnType)
				operator = Operators.get(reduction.name)
				left = varRef
				right = IrFactory::eINSTANCE.createParenthesis => 
				[ 
					expression = reductionInstr.reduction.arg
					type = EcoreUtil::copy(expression.type)
				]
			]
		}
		else
		{
			// creation de la fonction
			val f = findOrCreateFunction(m, reduction)										
			// transformation de la reduction
			return IrFactory::eINSTANCE.createFunctionCall =>
			[
				type = createExpressionType(f.returnType)
				function = f
				args += varRef
				args += reductionInstr.reduction.arg
			] 
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
				provider = r.provider
			]
			m.functions += function
		}
		
		return function
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

	private def createExpressionType(BasicType t)
	{
		IrFactory::eINSTANCE.createExpressionType => 
		[
			basicType = t
			dimension = 0
		]
	}
}