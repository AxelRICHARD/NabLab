/*******************************************************************************
 * Copyright (c) 2020 CEA
 * This program and the accompanying materials are made available under the 
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * SPDX-License-Identifier: EPL-2.0
 * Contributors: see AUTHORS file
 *******************************************************************************/
package fr.cea.nabla.ir

import fr.cea.nabla.ir.ir.ConnectivityCall
import fr.cea.nabla.ir.ir.SetRef
import fr.cea.nabla.ir.ir.Container

class ContainerExtensions 
{
	static def getConnectivity(Container it)
	{
		switch it
		{
			ConnectivityCall: connectivity
			SetRef: target.value.connectivity
		}
	}

	static def getUniqueName(Container it)
	{
		switch it
		{
			ConnectivityCall: connectivity.name + args.map[x | x.itemName.toFirstUpper].join('')
			SetRef: target.name
		}
	}

	static def getAccessor(ConnectivityCall it)
	'''get«connectivity.name.toFirstUpper»(«args.map[name].join(', ')»)'''
}