package fr.cea.nabla.generator.ir

import com.google.inject.Inject
import com.google.inject.Singleton
import fr.cea.nabla.ir.ir.Instruction
import fr.cea.nabla.ir.ir.IrFactory
import fr.cea.nabla.ir.ir.VarRef
import fr.cea.nabla.nabla.Affectation
import fr.cea.nabla.nabla.Expression
import fr.cea.nabla.nabla.If
import fr.cea.nabla.nabla.InstructionBlock
import fr.cea.nabla.nabla.Loop
import fr.cea.nabla.nabla.ReductionCall
import fr.cea.nabla.nabla.ScalarVarDefinition

/**
 * Attention : cette classe doit �tre un singleton car elle utilise des m�thodes create.
 * Si elle n'est pas singleton, plusieurs instances d'un m�me objet seront cr��es lors
 * deu parcours du graphe d'origine (voir la documentation Xtext).
 */
@Singleton
class IrInstructionFactory
{
	@Inject extension IrVariableFactory
	@Inject extension IrIteratorFactory
	@Inject extension IrExpressionFactory
	@Inject extension IrAnnotationHelper
	@Inject extension IrReductionInstructionFactory
	
	def dispatch Instruction toIrInstruction(ScalarVarDefinition v)
	{
		val irInstr = IrFactory::eINSTANCE.createScalarVarDefinition =>
		[
			annotations += v.toIrAnnotation
			variables += v.variable.toIrScalarVariable
		]

		return irInstr.transformReductions(v.defaultValue)
	}
	
	def dispatch create IrFactory::eINSTANCE.createInstructionBlock toIrInstruction(InstructionBlock v)
	{
		annotations += v.toIrAnnotation
		v.instructions.forEach[x | instructions += x.toIrInstruction]
	}

	def dispatch Instruction toIrInstruction(Affectation v)
	{
		val irInstr = IrFactory::eINSTANCE.createAffectation =>
		[
			annotations += v.toIrAnnotation
			left = v.varRef.toIrExpression as VarRef
			operator = '='
			right = v.expression.toIrExpression
		]

		return irInstr.transformReductions(v.expression)
	}
	
	def dispatch create IrFactory::eINSTANCE.createLoop toIrInstruction(Loop v)
	{
		annotations += v.toIrAnnotation
		iterator = v.iterator.toIrIterator
		body = v.body.toIrInstruction
	}
	
	def dispatch Instruction toIrInstruction(If v)
	{
		val irInstr = IrFactory::eINSTANCE.createIf =>
		[
			annotations += v.toIrAnnotation
			condition = v.condition.toIrExpression
			thenInstruction = v.then.toIrInstruction
			if (v.^else !== null) elseInstruction = v.^else.toIrInstruction
		]		
		
		return irInstr.transformReductions(v.condition)
	}
	
	private def Instruction transformReductions(Instruction i, Expression e)
	{
		if (e instanceof ReductionCall || e.eAllContents.exists(x | x instanceof ReductionCall))
			return IrFactory::eINSTANCE.createInstructionBlock =>
			[
				annotations += e.toIrAnnotation
				instructions += e.toIrReductions
				instructions += i
			]
		else
			return i
	}
}