#!/bin/sh
# First produce the base superglo in 01tmp

mkdir -p 01sig

superglo=`o2-cbdpp.sh`

cp $superglo 01tmp/superglo-for-lemmdata.glo

# dynamically merge work-in-progress projects into superglo
o2-super-dyn.sh $superglo

# import sigs from fully merged projects--these are projects
# that lemmatize directly from the superglo
superlang=`basename $superglo .glo`
o2-super-sig.sh $superlang

# create from_glos.sig
cbdpp.plx -sig $superglo

# harvest all the sigs from the projects' xtfs 
# (i.e., 01bld/from-xtf-glo.sig).
echo "o2-super-prep.sh: getting sigs via 00map and 01map"
for a in 00map/*.map ; do
    super-getsigs.plx $a
done

# Now treat all of the imported sigs as proxies, which
# they effectively are.
echo "o2-super-prep.sh: creating 01bld/from-prx-glo.sig"
echo "@fields sig inst" >01bld/from-prx-glo.sig
grep -h -v '@\(project\|lang\|name\|fields\)' 01sig/*.sig | perl -p -e 's/\@.*?\%/\@epsd2%/g' >>01bld/from-prx-glo.sig

# create lemm-sux.sig based on the original glossary so it has all the instances
# possible in its statistics but it isn't contaminated by forms only inducted via
# superdyn, 
l2p1-lemm-data.plx -g 01tmp/superglo-for-lemmdata.glo
touch .nolemmdata
