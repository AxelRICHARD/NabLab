package fr.cea.nabla.ui.handlers

import com.google.inject.Inject
import com.google.inject.Provider
import com.google.inject.Singleton
import fr.cea.nabla.generator.NablaGeneratorMessageDispatcher.MessageType
import fr.cea.nabla.generator.NablagenInterpreter
import fr.cea.nabla.ir.Utils
import fr.cea.nabla.nablagen.NablagenRoot
import org.eclipse.core.resources.IFile
import org.eclipse.core.resources.IResource
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.swt.SWT
import org.eclipse.swt.widgets.Shell

@Singleton
class GenerateApplicationHandler extends AbstractGenerateHandler
{
	@Inject Provider<ResourceSet> resourceSetProvider
	@Inject Provider<NablagenInterpreter> interpreterProvider

	override generate(IFile nablagenFile, Shell shell)
	{
		val interpreter = interpreterProvider.get
		val project = nablagenFile.project

		consoleFactory.openConsole
		val traceFunction = [MessageType type, String msg | consoleFactory.printConsole(type, msg)]
		dispatcher.traceListeners += traceFunction

		new Thread
		([
			try
			{
				consoleFactory.clearAndActivateConsole
				consoleFactory.printConsole(MessageType.Start, "Starting generation process for: " + nablagenFile.name)
				consoleFactory.printConsole(MessageType.Exec, "Loading nablagen and nabla resources")
				val plaftormUri = URI::createPlatformResourceURI(project.name + '/' + nablagenFile.projectRelativePath, true)
				val resourceSet = resourceSetProvider.get
				val uriMap = resourceSet.URIConverter.URIMap
				uriMap.put(URI::createURI('platform:/resource/fr.cea.nabla/'), URI::createURI('platform:/plugin/fr.cea.nabla/'))
				val emfResource = resourceSet.createResource(plaftormUri)
				EcoreUtil::resolveAll(resourceSet)
				emfResource.load(null)

				consoleFactory.printConsole(MessageType.Exec, "Starting NabLab to IR model transformation")
				val startTime = System.currentTimeMillis
				val baseDir = project.location.toString
				val ngen = emfResource.contents.filter(NablagenRoot).head
				val ir = interpreter.buildIr(ngen, baseDir, false)
				val afterConvertionTime = System.currentTimeMillis
				consoleFactory.printConsole(MessageType.Exec, "NabLab to IR model transformation ended in " + (afterConvertionTime-startTime)/1000.0 + "s")

				consoleFactory.printConsole(MessageType.Exec, "Starting code generation")
				shell.display.syncExec([shell.cursor = shell.display.getSystemCursor(SWT.CURSOR_WAIT)])
				interpreter.generateCode(ir, ngen.genTargets, ngen.mainModule.iterationMax.name, ngen.mainModule.timeMax.name, baseDir, ngen.levelDB)
				shell.display.syncExec([shell.cursor = null])
				val afterGenerationTime = System.currentTimeMillis
				consoleFactory.printConsole(MessageType.Exec, "Code generation ended in " + (afterGenerationTime-afterConvertionTime)/1000.0 + "s")
				consoleFactory.printConsole(MessageType.Exec, "Total time: " + (afterGenerationTime-startTime)/1000.0 + "s");

				project.refreshLocal(IResource::DEPTH_INFINITE, null)
				consoleFactory.printConsole(MessageType.End, "Generation ended successfully for: " + nablagenFile.name)
			}
			catch (Exception e)
			{
				shell.display.syncExec([shell.cursor = null])
				consoleFactory.printConsole(MessageType.Error, "Generation failed for: " + nablagenFile.name)
				consoleFactory.printConsole(MessageType.Error, e.message)
				consoleFactory.printConsole(MessageType.Error, Utils.getStackTrace(e))
			}
		]).start

		dispatcher.traceListeners -= traceFunction
	}
}