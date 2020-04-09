/*******************************************************************************
 * Copyright (c) 2020 CEA
 * This program and the accompanying materials are made available under the 
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * SPDX-License-Identifier: EPL-2.0
 * Contributors: see AUTHORS file
 *******************************************************************************/
package fr.cea.nabla.tests.validation

import com.google.inject.Inject
import fr.cea.nabla.nabla.NablaModule
import fr.cea.nabla.nabla.NablaPackage
import fr.cea.nabla.nabla.PrimitiveType
import fr.cea.nabla.tests.NablaInjectorProvider
import fr.cea.nabla.tests.TestUtils
import fr.cea.nabla.validation.FunctionOrReductionValidator
import org.eclipse.xtext.diagnostics.Severity
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.eclipse.xtext.testing.util.ParseHelper
import org.eclipse.xtext.testing.validation.ValidationTestHelper
import org.junit.Assert
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(typeof(XtextRunner))
@InjectWith(typeof(NablaInjectorProvider))
class FunctionOrReductionValidatorTest
{
	@Inject ParseHelper<NablaModule> parseHelper
	@Inject extension TestUtils
	@Inject extension ValidationTestHelper

	@Test
	def void testCheckForbiddenReturn()
	{
		val moduleKo = parseHelper.parse(getTestModule(defaultConnectivities, '')
			+
			'''
			ℕ U{cells};
			ComputeU: ∀ j∈cells(), {
					let e = 1;
					U{j} = e * 4;
					return e;
			}
			'''
		)
		Assert.assertNotNull(moduleKo)
		moduleKo.assertError(NablaPackage.eINSTANCE.^return,
			FunctionOrReductionValidator::FORBIDDEN_RETURN,
			FunctionOrReductionValidator::getForbiddenReturnMsg())

		val moduleOk = parseHelper.parse(getTestModule(defaultConnectivities, '')
			+
			'''
			ℕ U{cells};
			ComputeU: ∀ j∈cells(), {
					let e = 1;
					U{j} = e * 4;
			}
			'''
		)
		Assert.assertNotNull(moduleOk)
		moduleOk.assertNoErrors
	}

	@Test
	def void testCheckMissingReturn()
	{
		val moduleKo = parseHelper.parse(
		'''
		module Test;

		def f: ℝ → ℝ, (a) → { let x = 1; }
		''')
		Assert.assertNotNull(moduleKo)
		moduleKo.assertError(NablaPackage.eINSTANCE.functionOrReduction,
			FunctionOrReductionValidator::MISSING_RETURN,
			FunctionOrReductionValidator::getMissingReturnMsg())

		val moduleOk = parseHelper.parse(
		'''
		module Test;

		def f: ℝ → ℝ, (a) → { return 1.0; }
		''')
		Assert.assertNotNull(moduleOk)
	}

	@Test
	def void testCheckUnreachableCode()
	{
		val moduleKo = parseHelper.parse(
		'''
		module Test;

		def f: ℝ → ℝ, (a) → 
		{
			return 1.0;
			let x = 1;
		}
		''')
		Assert.assertNotNull(moduleKo)
		moduleKo.assertError(NablaPackage.eINSTANCE.simpleVarDefinition,
			FunctionOrReductionValidator::UNREACHABLE_CODE,
			FunctionOrReductionValidator::getUnreachableReturnMsg())

		val moduleOk = parseHelper.parse(
		'''
		module Test;

		def f: ℝ → ℝ, (a) → 
		{ 
			return 1.0;
		}
		''')
		Assert.assertNotNull(moduleOk)
	}

	@Test
	def void testCheckOnlyIntAndVarInFunctionInTypes()
	{
		val modulekO = parseHelper.parse(getTestModule('', '''def f: x | ℝ[x+1] → ℝ[x];'''))
		Assert.assertNotNull(modulekO)

		modulekO.assertError(NablaPackage.eINSTANCE.function,
			FunctionOrReductionValidator::ONLY_INT_AND_VAR_IN_FUNCTION_IN_TYPES,
			FunctionOrReductionValidator::getOnlyIntAndVarInFunctionInTypesMsg(#["x"]))

		val moduleOk = parseHelper.parse(getTestModule('', '''def f: x | ℝ[x] → ℝ[x+1];'''))
		Assert.assertNotNull(moduleOk)
		moduleOk.assertNoErrors
	}

	@Test
	def testCheckOnlyIntAndVarInReductionType()
	{
		val modulekO = parseHelper.parse(getTestModule('', '''def sum, 0.0: x,y | ℝ[x+y], (a,b) → return a + b;'''))
		Assert.assertNotNull(modulekO)

		modulekO.assertError(NablaPackage.eINSTANCE.reduction,
			FunctionOrReductionValidator::ONLY_INT_AND_VAR_IN_REDUCTION_TYPE,
			FunctionOrReductionValidator::getOnlyIntAndVarInReductionTypeMsg(#["x, y"]))

		val moduleOk = parseHelper.parse(getTestModule('', '''def sum, 0.0: x | ℝ[x], (a,b) → return a + b;'''))
		Assert.assertNotNull(moduleOk)
		moduleOk.assertNoErrors
	}

	@Test
	def void testCheckFunctionInvalidArgNumber()
	{
		val moduleKo = parseHelper.parse(
		'''
		module Test;

		def f: ℝ → ℝ, (a, b) → 
		{
			return 1.0;
		}
		''')
		Assert.assertNotNull(moduleKo)
		moduleKo.assertError(NablaPackage.eINSTANCE.functionOrReduction,
			FunctionOrReductionValidator::FUNCTION_INVALID_ARG_NUMBER,
			FunctionOrReductionValidator::getFunctionInvalidArgNumberMsg())

		val moduleOk = parseHelper.parse(
		'''
		module Test;

		def f: ℝ → ℝ, (a) → 
		{ 
			return 1.0;
		}
		''')
		Assert.assertNotNull(moduleOk)
	}

	@Test
	def void testCheckFunctionIncompatibleInTypes() 
	{
		var functions =
			'''
			def g: ℝ[2] → ℝ;
			def g: x | ℝ[x] → ℝ;
			'''

		val modulekO = parseHelper.parse(getTestModule('', functions))
		Assert.assertNotNull(modulekO)

		modulekO.assertError(NablaPackage.eINSTANCE.function,
			FunctionOrReductionValidator::FUNCTION_INCOMPATIBLE_IN_TYPES,
			FunctionOrReductionValidator::getFunctionIncompatibleInTypesMsg())

		functions =
			'''
			def g: ℝ → ℝ;
			def g: x | ℝ[x] → ℝ;
			'''

		val moduleOk = parseHelper.parse(getTestModule('', functions))
		Assert.assertNotNull(moduleOk)
		moduleOk.assertNoErrors
	}

	@Test
	def void testFunctionReturnType()
	{
		val module = parseHelper.parse(
		'''
		module Test;

		itemtypes { node }
		set nodes: → {node};

		def f: ℝ → ℝ, (a) → { return 1; }
		def g: ℝ → ℝ, (a) → { return 1.0; }
		'''
		+ mandatoryOptions)

		Assert.assertNotNull(module)
		Assert.assertEquals(1, module.validate.filter(i | i.severity == Severity.ERROR).size)
		module.assertError(NablaPackage.eINSTANCE.function, FunctionOrReductionValidator::FUNCTION_RETURN_TYPE, FunctionOrReductionValidator::getFunctionReturnTypeMsg("ℕ", "ℝ"))
	}

	@Test
	def void testCheckFunctionReturnTypeVar() 
	{
		var functions = '''def f: x | ℝ → ℝ[x];'''

		val modulekO = parseHelper.parse(getTestModule('', functions))
		Assert.assertNotNull(modulekO)

		modulekO.assertError(NablaPackage.eINSTANCE.function, 
			FunctionOrReductionValidator::FUNCTION_RETURN_TYPE_VAR, 
			FunctionOrReductionValidator::getFunctionReturnTypeVarMsg("x"))

		functions =
			'''
			def f: x | ℝ[x] → ℝ[x];
			def g: y | ℝ[y] → ℝ[x, y];
			'''

		val moduleOk = parseHelper.parse(getTestModule('', functions))
		Assert.assertNotNull(moduleOk)
		moduleOk.assertNoErrors(NablaPackage.eINSTANCE.function, FunctionOrReductionValidator::FUNCTION_RETURN_TYPE_VAR)
	}

	@Test
	def void testCheckReductionIncompatibleTypes() 
	{
		var reductions =
			'''
			def g, 0.0: ℝ[2], (a, b) → return a;
			def g, 0.0: x | ℝ[x], (a, b) → return a;
			'''
		val modulekO = parseHelper.parse(getTestModule('', reductions))
		Assert.assertNotNull(modulekO)

		modulekO.assertError(NablaPackage.eINSTANCE.reduction,
			FunctionOrReductionValidator::REDUCTION_INCOMPATIBLE_TYPES,
			FunctionOrReductionValidator::getReductionIncompatibleTypesMsg())

		reductions =
			'''
			def g, 0.0: ℝ, (a, b) → return a;
			def g, 0.0: x | ℝ[x], (a, b) → return a;
			'''
		val moduleOk = parseHelper.parse(getTestModule('', reductions))
		Assert.assertNotNull(moduleOk)
		moduleOk.assertNoErrors
	}

	@Test
	def void testCheckSeedAndTypes()
	{
		val moduleKo = parseHelper.parse(getTestModule ('',
				'''
				def sum1, [0.0, 0.0]: ℝ[2], (a, b) → return a + b;
				def sum1, 0.0: ℕ, (a, b) → return a + b;
				'''
			)
		)
		Assert.assertNotNull(moduleKo)

		moduleKo.assertError(NablaPackage.eINSTANCE.reduction,
			FunctionOrReductionValidator::REDUCTION_SEED_TYPE,
			FunctionOrReductionValidator::getReductionSeedTypeMsg())

		moduleKo.assertError(NablaPackage.eINSTANCE.reduction,
			FunctionOrReductionValidator::REDUCTION_TYPES_COMPATIBILITY,
			FunctionOrReductionValidator::getReductionTypesCompatibilityMsg(PrimitiveType::REAL.literal, PrimitiveType::INT.literal))

		val moduleOk = parseHelper.parse(getTestModule( '',
				'''
				def sum1, 0.0: ℝ[2], (a, b) → return a + b;
				def sum1, 0: ℕ, (a, b) → return a + b;
				'''
			)
		)
		Assert.assertNotNull(moduleOk)
		moduleOk.assertNoErrors
	}
}