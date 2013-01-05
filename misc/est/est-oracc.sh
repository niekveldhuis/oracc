#!/bin/sh
cd ~/www
rm -fr estindex
echo Rebuilding Oracc full text index ...
# Don't index the Oracc home files because they are just noise
# from the perspective of finding content and documentation.
# ls *.html | estcmd gather -tr -ic UTF-8 estindex - >/dev/null 2>&1
find doc | grep -v wwwhome | estcmd gather -ic UTF-8 estindex - >/dev/null 2>&1
estcmd gather -ic UTF-8 estindex ns >/dev/null 2>&1
chmod -R o+r estindex
for a in `agg-list-public-projects.sh`; do
    # add CDLI or not?
    if [ "$a" != "cdli" ]; then
	echo merging $a full text index into Oracc index ...
	estcmd merge estindex $a/estindex >/dev/null 2>&1
    fi
done
