#!/bin/sh
o2-prepare.sh
buildpolicy=`oraccopt . build-approved-policy`;
if [ "$buildpolicy" != "search" ]; then
    umbrella=`oraccopt . cbd-super`;
    if [ "$umbrella" = "umbrella" ]; then
	echo "o2-corpus.sh: getting sigs via umbrella.lst"
	echo '@fields sig inst' >01bld/from-prx-glo.sig
	for a in `cat 00lib/umbrella.lst` ; do
	    grep '%' $a/01bld/from-xtf-glo.sig >>01bld/from-prx-glo.sig
	done
    else
	echo "o2-corpus.sh: getting sigs from corpus"
	[ -s 01bld/lists/have-lem.lst ] && l2p1-from-xtfs.plx -t 01bld/lists/have-lem.lst
	[ -s 01bld/lists/proxy-lem.lst ] && l2p1-from-xtfs.plx -proxy -t 01bld/lists/proxy-lem.lst
    fi
else
    echo "o2-corpus.sh: getting sigs via umbrella.lst"
    echo '@fields sig inst' >01bld/from-prx-glo.sig
    for a in `cat 00lib/search.lst` ; do
	xsig=$a/01bld/from-xtf-glo.sig
	psig=$a/01bld/from-prx-glo.sig
	if [ -r $xsig ]; then
	    grep '%' $xsig >>01bld/from-prx-glo.sig
	fi
	if [ -r $psig ]; then
	    grep '%' $psig >>01bld/from-prx-glo.sig
	fi
    done
    sig-langs.sh 01bld/from-prx-glo.sig >01bld/superlangs
    /bin/echo -n ' qpn' >>01bld/superlangs
fi
o2-glo.sh
o2-xtf.sh $*
#o2-web.sh
o2-web-corpus.sh
#o2-prm.sh
o2-weblive.sh
o2-finish.sh
