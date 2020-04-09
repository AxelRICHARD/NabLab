/*******************************************************************************
 * Copyright (c) 2020 CEA
 * This program and the accompanying materials are made available under the 
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * SPDX-License-Identifier: EPL-2.0
 * Contributors: see AUTHORS file
 *******************************************************************************/
package fr.cea.nabla.validation

import com.google.inject.Inject
import fr.cea.nabla.nabla.ArgOrVarRef
import fr.cea.nabla.nabla.BaseType
import fr.cea.nabla.nabla.Function
import fr.cea.nabla.nabla.FunctionOrReduction
import fr.cea.nabla.nabla.InstructionBlock
import fr.cea.nabla.nabla.IntConstant
import fr.cea.nabla.nabla.NablaModule
import fr.cea.nabla.nabla.NablaPackage
import fr.cea.nabla.nabla.Reduction
import fr.cea.nabla.nabla.Return
import fr.cea.nabla.nabla.SimpleVar
import fr.cea.nabla.typing.BaseTypeTypeProvider
import java.util.HashSet
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.validation.Check
import fr.cea.nabla.typing.ExpressionTypeProvider
import fr.cea.nabla.typing.NSTScalar
import fr.cea.nabla.nabla.Expression

class FunctionOrReductionValidator extends BasicValidator
{
	@Inject extension ValidationUtils
	@Inject extension BaseTypeTypeProvider
	@Inject extension ExpressionTypeProvider

	public static val FORBIDDEN_RETURN = "Functions::Forbidden"
	public static val MISSING_RETURN = "Functions::Missing"
	public static val UNREACHABLE_CODE = "Functions::UnreachableCode"
	public static val ONLY_INT_AND_VAR_IN_FUNCTION_IN_TYPES = "Functions::OnlyIntAndVarInFunctionInTypes"
	public static val ONLY_INT_AND_VAR_IN_REDUCTION_TYPE = "Functions::OnlyIntAndVarInReductionType"
	public static val FUNCTION_INVALID_ARG_NUMBER = "Functions::InvalidArgNumber"
	public static val FUNCTION_INCOMPATIBLE_IN_TYPES = "Functions::FunctionIncompatibleInTypes"
	public static val FUNCTION_RETURN_TYPE = "Functions::FunctionReturnType"
	public static val FUNCTION_RETURN_TYPE_VAR = "Functions::FunctionReturnTypeVar"
	public static val REDUCTION_INCOMPATIBLE_TYPES = "Functions::ReductionIncompatibleTypes"
	public static val REDUCTION_SEED_TYPE = "Functions::ReductionSeedType"
	public static val REDUCTION_TYPES_COMPATIBILITY = "Functions::ReductionTypesCompatibility"

	static def getForbiddenReturnMsg() { "Return instruction only allowed in functions" }
	static def getMissingReturnMsg() { "Function/Reduction must end with a return instruction" }
	static def getUnreachableReturnMsg() { "Unreachable code" }
	static def getOnlyIntAndVarInFunctionInTypesMsg(String[] allowedVarNames) { buildMsg("In types", allowedVarNames) }
	static def getOnlyIntAndVarInReductionTypeMsg(String[] allowedVarNames) { buildMsg("Type", allowedVarNames) }
	static def getFunctionInvalidArgNumberMsg() { "Number of arguments must be equal to number of input types" }
	static def getFunctionIncompatibleInTypesMsg() { "Declaration conflicts" }
	static def getFunctionReturnTypeMsg(String actualTypeName, String expectedTypeName) { "Wrong return type. Expected " + expectedTypeName + ", but was " + actualTypeName }
	static def getFunctionReturnTypeVarMsg(String variableName) { "Only input type variables can be used for return types. Invalid variable: " + variableName }
	static def getReductionIncompatibleTypesMsg() { "Declaration conflicts" }
	static def getReductionSeedTypeMsg() { "Seed type must be scalar" }
	static def getReductionTypesCompatibilityMsg(String seedType, String type) { "Seed type and reduction type are incompatible: " + seedType + " and " + type }

	@Check
	def checkForbiddenReturn(Return it)
	{
		val function = EcoreUtil2.getContainerOfType(it, FunctionOrReduction)
		if (function === null)
			error(getForbiddenReturnMsg(), NablaPackage.Literals.RETURN__EXPRESSION, FORBIDDEN_RETURN)
	}

	@Check
	def checkMissingReturn(FunctionOrReduction it)
	{
		if (body === null) return;

		val hasReturn = (body instanceof Return) || body.eAllContents.exists[x | x instanceof Return]
		if (!hasReturn)
			error(getMissingReturnMsg(), NablaPackage.Literals.FUNCTION_OR_REDUCTION__NAME, MISSING_RETURN)
	}

	@Check
	def checkUnreachableCode(FunctionOrReduction it)
	{
		if (body === null) return;
		
		if (body instanceof InstructionBlock)
		{
			val instructions = (body as InstructionBlock).instructions
			for (i : 0..<instructions.size-1)
				if (instructions.get(i) instanceof Return)
				{
					error(getUnreachableReturnMsg(), instructions.get(i+1), null, UNREACHABLE_CODE)
					return // no need to return further errors
				}
		}
	}

	@Check
	def checkOnlyIntAndVarInFunctionInTypes(Function it)
	{
		for (inType : inTypes)
			if (!inType.sizes.forall[x | isAllowedInFunctionOrReduction(it, x)])
				error(getOnlyIntAndVarInFunctionInTypesMsg(vars.map[name]), NablaPackage.Literals::FUNCTION__IN_TYPES, ONLY_INT_AND_VAR_IN_FUNCTION_IN_TYPES)
	}

	@Check
	def checkOnlyIntAndVarInReductionType(Reduction it)
	{
		if (!type.sizes.forall[x | isAllowedInFunctionOrReduction(it, x)])
			error(getOnlyIntAndVarInReductionTypeMsg(vars.map[name]), NablaPackage.Literals::REDUCTION__TYPE, ONLY_INT_AND_VAR_IN_REDUCTION_TYPE)
	}

	@Check
	def checkFunctionIncompatibleInTypes(Function it)
	{
		if (!external && inTypes.size !== inArgs.size)
		{
			error(getFunctionInvalidArgNumberMsg(), NablaPackage.Literals::FUNCTION_OR_REDUCTION__IN_ARGS, FUNCTION_INVALID_ARG_NUMBER)
			return
		}

		val module = eContainer as NablaModule
		val otherFunctionArgs = module.functions.filter(Function).filter[x | x.name == name && x !== it]
		val conflictingFunctionArg = otherFunctionArgs.findFirst[x | !areCompatible(x, it)]
		if (conflictingFunctionArg !== null)
			error(getFunctionIncompatibleInTypesMsg(), NablaPackage.Literals::FUNCTION_OR_REDUCTION__NAME, FUNCTION_INCOMPATIBLE_IN_TYPES)
	}

	@Check
	def checkFunctionReturnType(Function it)
	{
		if (!external && body !== null)
		{
			val returnInstruction = if (body instanceof Return) body as Return else body.eAllContents.findFirst[x | x instanceof Return]
			if (returnInstruction !== null)
			{
				val ri = returnInstruction as Return
				val expressionType = ri.expression?.typeFor
				val fType = returnType.typeFor
				if (expressionType !== null && !checkExpectedType(expressionType, fType))
					error(getFunctionReturnTypeMsg(expressionType.label, fType.label), NablaPackage.Literals.FUNCTION__RETURN_TYPE, FUNCTION_RETURN_TYPE)
			}
		}
	}

	@Check
	def checkFunctionReturnTypeVar(Function it)
	{
		val inTypeVars = new HashSet<SimpleVar>
		for (inType : inTypes)
			for (dim : inType.eAllContents.filter(ArgOrVarRef).toIterable)
				if (dim.target !== null && !dim.target.eIsProxy && dim.target instanceof SimpleVar)
					inTypeVars += dim.target as SimpleVar

		val returnTypeVars = new HashSet<SimpleVar>
		for (dim : returnType.eAllContents.filter(ArgOrVarRef).toIterable)
			if (dim.target !== null && !dim.target.eIsProxy && dim.target instanceof SimpleVar)
				returnTypeVars += dim.target as SimpleVar

		val x = returnTypeVars.findFirst[x | !inTypeVars.contains(x)]
		if (x !== null)
			error(getFunctionReturnTypeVarMsg(x.name), NablaPackage.Literals::FUNCTION__RETURN_TYPE, FUNCTION_RETURN_TYPE_VAR)
	}

	@Check
	def checkReductionIncompatibleTypes(Reduction it)
	{
		val otherReductionArgs = eContainer.eAllContents.filter(Reduction).filter[x | x.name == name && x !== it]
		val conflictingReductionArg = otherReductionArgs.findFirst[x | !areCompatible(x.type, type)]
		if (conflictingReductionArg !== null)
			error(getReductionIncompatibleTypesMsg(), NablaPackage.Literals::REDUCTION__TYPE, REDUCTION_INCOMPATIBLE_TYPES)
	}

	@Check
	def checkSeedAndType(Reduction it)
	{
		val seedType = seed?.typeFor
		// Seed must be scalar and Seed rootType must be the same as Return rootType
		// If type is Array, the reduction Seed will be used as many times as Array size
		// Ex (ℕ.MaxValue, ℝ])→ℕ[2]; -> we will use (ℕ.MaxValue, ℕ.MaxValue) as reduction seed
		if (seedType !== null)
		{
			val rType = type.primitive
			if (!(seedType instanceof NSTScalar))
				error(getReductionSeedTypeMsg(), NablaPackage.Literals.REDUCTION__SEED, REDUCTION_SEED_TYPE)
			else if (seedType.label != rType.literal)
				error(getReductionTypesCompatibilityMsg(seedType.label, rType.literal), NablaPackage.Literals.REDUCTION__SEED, REDUCTION_TYPES_COMPATIBILITY)
		}
	}

		/** 
	 * Returns true if a and b can be declared together, false otherwise. 
	 * For example, false for R[2]->R and R[n]->R
	 */
	private def areCompatible(Function a, Function b)
	{
		if (a.inTypes.size != b.inTypes.size)
			return true

		for (i : 0..<a.inTypes.size)
			if (areCompatible(a.inTypes.get(i), b.inTypes.get(i)))
				return true

		return false
	}

	private def areCompatible(BaseType a, BaseType b)
	{
		(a.primitive != b.primitive || a.sizes.size != b.sizes.size)
	}

	/**
	 * Returns true if the expression expr is an IntConstant
	 * or an ArgOrVarRef referencing a variable defined
	 * in f, else otherwise
	 */
	private def isAllowedInFunctionOrReduction(FunctionOrReduction f, Expression expr)
	{
		switch expr
		{
			IntConstant: true
			ArgOrVarRef case expr.target.eContainer === f: true
			default: false
		}
	}

	private static def buildMsg(String prefix, String[] allowedVarNames) 
	{
		var msg = prefix + " must only contain int constants"
		if (!allowedVarNames.empty)
			msg += ", " + allowedVarNames.join(', ')
		return msg
	}
}