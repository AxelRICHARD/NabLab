#
#!/bin/bash
#

OLD_VERSION=0.1.0
NEW_VERSION=0.1.2

echo "Looking for MANIFEST.MF files"
FIND_RES=`find . -path ./.metadata -prune -o -name "MANIFEST.MF" -print`
for f in $FIND_RES
do
   if grep -q "Bundle-Vendor: CEA" $f; then
      if grep -q "Bundle-Version: $OLD_VERSION.qualifier" $f; then
         echo "   Changing version of:" $f
         cp $f $f.old
         sed "s/Bundle-Version: $OLD_VERSION.qualifier/Bundle-Version: $NEW_VERSION.qualifier/g" $f.old > $f
      fi
   fi
done

echo "Looking for pom.xml files"
FIND_RES=`find . -path ./.metadata -prune -o -name "pom.xml" -print`
for f in $FIND_RES
do
   if grep -q "<groupId>fr.cea.nabla</groupId>" $f; then
      if grep -q "<version>$OLD_VERSION-SNAPSHOT</version>" $f; then
         echo "   Changing version of:" $f
         cp $f $f.old
         sed "s%<version>$OLD_VERSION-SNAPSHOT</version>%<version>$NEW_VERSION-SNAPSHOT</version>%g" $f.old > $f
      fi
   fi
done

echo "Looking for feature.xml files"
FIND_RES=`find . -path ./.metadata -prune -o -name "feature.xml" -print`
for f in $FIND_RES
do
   if grep -q "provider-name=\"CEA\"" $f; then
      if grep -q "version=\"$OLD_VERSION.qualifier\"" $f; then
         echo "   Changing version of:" $f
         cp $f $f.old
         sed "s/version=\"$OLD_VERSION.qualifier\"/version=\"$NEW_VERSION.qualifier\"/g" $f.old > $f
      fi
   fi
done

f=./plugins/fr.cea.nabla.rcp/plugin.xml
if grep -q "Version $OLD_VERSION" $f; then
   echo "   Changing version of:" $f
   cp $f $f.old
   sed "s/Version $OLD_VERSION/Version $NEW_VERSION/g" $f.old > $f
fi

echo "DONE. All that remains is to change the SPLASH SCREEN (BMP 459x347)."
