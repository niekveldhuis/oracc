#!/bin/sh
project=`oraccopt`
if [ "$project" == "" ]; then
    echo otf2odt.sh: must be run from a project directory
    exit 1
fi
driverpath=$1
if [ "$driverpath" == "" ]; then
    if [ -r 00lib/project.otf ]; then
	driverpath=00lib/project.otf
    else
	echo otf2odt.sh: no .otf file given on command line and no 00lib/project.otf
	exit 1
    fi
fi
keep=$2
driverdir=`dirname $driverpath`
drivername=`basename $driverpath`
odtdir=01bld/`basename $drivername .otf`
rm -fr $odtdir ; mkdir -p $odtdir
echo ox -P$project -d$odtdir $driverpath
ox -P$project -d$odtdir $driverpath | xmllint --xinclude - | xsltproc - \
    | xsltproc ${ORACC}/lib/scripts/odt-table-width.xsl - \
    | xsltproc -stringparam package "$odtdir" ${ORACC}/lib/scripts/doc-split.xsl -
cwd=`pwd`; cd $odtdir
mkdir -p META-INF
echo '<?xml version="1.0" encoding="utf-8"?>' >META-INF/manifest.xml
echo '<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0">' \
    >>META-INF/manifest.xml 
echo '<manifest:file-entry manifest:media-type="application/vnd.oasis.opendocument.text" manifest:full-path="/"/>' \
    >>META-INF/manifest.xml
for a in *.xml ; \
    do echo "<manifest:file-entry manifest:media-type=\"text/xml\" manifest:full-path=\"$a\"/>" \
    >>META-INF/manifest.xml ; \
done
mkdir -p pictures ; odtpictures.plx >>META-INF/manifest.xml
echo '</manifest:manifest>' >>META-INF/manifest.xml
echo -n 'application/vnd.oasis.opendocument.text' >mimetype
pwd
zip -q -X ../`basename $odtdir`.odt mimetype
zip -q -X -g -r ../`basename $odtdir`.odt *.xml META-INF
cd $cwd
