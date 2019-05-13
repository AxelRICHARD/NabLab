#!/bin/sh

P=fr.cea.nabla
echo PROJET $P > appList.txt
find $P/src -name "*.*" >> appList.txt
find $P/src-gen -name "*.*" >> appList.txt
find $P/model -name "*.*" >> appList.txt

P=fr.cea.nabla.edit
echo >> appList.txt
echo PROJET $P >> appList.txt
find $P/src -name "*.*" >> appList.txt

P=fr.cea.nabla.editor
echo >> appList.txt
echo PROJET $P >> appList.txt
find $P/src -name "*.*" >> appList.txt

P=fr.cea.nabla.ui
echo >> appList.txt
echo PROJET $P >> appList.txt
find $P/src -name "*.*" >> appList.txt

P=fr.cea.nabla.ide
echo >> appList.txt
echo PROJET $P >> appList.txt
find $P/src -name "*.*" >> appList.txt

P=fr.cea.nabla.tests
echo >> appList.txt
echo PROJET $P >> appList.txt
find $P/src -name "*.*" >> appList.txt

P=fr.cea.nabla.javalib
echo >> appList.txt
echo PROJET $P >> appList.txt
find $P/src -name "*.*" >> appList.txt

P=fr.cea.nabla.cpplib
echo >> appList.txt
echo PROJET $P >> appList.txt
find $P/src -name "*.*" >> appList.txt

P=fr.cea.nabla.ir
echo >> appList.txt
echo PROJET $P >> appList.txt
find $P/src -name "*.*" >> appList.txt
find $P/model -name "*.*" >> appList.txt

P=fr.cea.nabla.sirius
echo >> appList.txt
echo PROJET $P >> appList.txt
find $P/src -name "*.*" >> appList.txt
find $P/description -name "*.*" >> appList.txt
