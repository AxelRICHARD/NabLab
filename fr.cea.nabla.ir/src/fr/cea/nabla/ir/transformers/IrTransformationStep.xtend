package fr.cea.nabla.ir.transformers

import fr.cea.nabla.ir.ir.IrModule

interface IrTransformationStep 
{
	def String getDescription()
	/** Retourne vrai si la passe s'est correctement d�roul�e, faux sinon */
	def boolean transform(IrModule m)
}