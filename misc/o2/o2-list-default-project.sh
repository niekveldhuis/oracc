#!/bin/sh
perl -p -e "!/:/ && s/^/$1:/" <$2 >$3
