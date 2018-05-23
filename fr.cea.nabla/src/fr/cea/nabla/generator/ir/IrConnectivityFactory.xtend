package fr.cea.nabla.generator.ir

import com.google.inject.Inject
import com.google.inject.Singleton
import fr.cea.nabla.ir.ir.IrFactory
import fr.cea.nabla.nabla.Connectivity

/**
 * Attention : cette classe doit �tre un singleton car elle utilise des m�thodes create.
 * Si elle n'est pas singleton, plusieurs instances d'un m�me objet seront cr��es lors
 * deu parcours du graphe d'origine (voir la documentation Xtext).
 */
@Singleton
class IrConnectivityFactory 
{
	@Inject extension Nabla2IrUtils
	@Inject extension IrAnnotationHelper

	def create IrFactory::eINSTANCE.createConnectivity toIrConnectivity(Connectivity c)
	{
		annotations += c.toIrAnnotation
		name = c.name
		returnType = c.returnType.toIrItemArgType
		inTypes += c.inTypes.map[toIrItemType]
	}	
}