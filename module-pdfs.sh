#!/bin/sh

# 1st arg is the path to the collection
# 2nd arg (optional) is the module name

echo "NOTE: You will need to change lib/fop.xconf to point to absolute paths!"
echo "      Otherwise, errors will arise below!!!"

COL_PATH=$1

ROOT=`pwd`

# FOP Needs a lot of memory (4+Gb for Elementary Algebra)
declare -x FOP_OPTS=-Xmx14000M

XSLTPROC="xsltproc --nonet"
FOP="bash $ROOT/fop/fop -c $ROOT/lib/fop.xconf"

# XSL files
DOCBOOK_CLEANUP_XSL=$ROOT/xsl/docbook-cleanup-whole.xsl
DOCBOOK2FO_XSL=$ROOT/xsl/docbook2fo.xsl
ALIGN_XSL=$ROOT/xsl/postprocess-svg.xsl

MODULES=`ls $COL_PATH`
if [ $2 != '' ]; then MODULES=$2; fi

for MODULE in $MODULES
do
    if [ -d $COL_PATH/$MODULE ];
    then
        echo "Converting $MODULE"

        DOCBOOK=$COL_PATH/$MODULE/index.dbk
        DOCBOOK2=$COL_PATH/$MODULE/index.cleaned.dbk
        UNALIGNED=$COL_PATH/$MODULE/index.fo
        FO=index.aligned.fo
        PDF=index.pdf

        $XSLTPROC --xinclude -o $DOCBOOK2 $DOCBOOK_CLEANUP_XSL $DOCBOOK
        
        $XSLTPROC -o $UNALIGNED $DOCBOOK2FO_XSL $DOCBOOK2  2> $COL_PATH/$MODULE/_err.log
        $XSLTPROC -o $COL_PATH/$MODULE/$FO $ALIGN_XSL $UNALIGNED 2> /dev/null
        
        # Change to the collection dir so the relative paths to images work
        cd $COL_PATH/$MODULE
        time $FOP $FO $PDF > _fop.log 2> _fop.err.log
        ERR_CODE=$?
        cd $ROOT

        if [ $ERR_CODE -eq 0 ];
        then
            rm $COL_PATH/$MODULE/_err.log 2> /dev/null
            rm $COL_PATH/$MODULE/_fop.log 2> /dev/null
            rm $COL_PATH/$MODULE/_fop.err.log 2> /dev/null
            rm $DOCBOOK2 2> /dev/null
            rm $UNALIGNED 2> /dev/null
            rm $FO 2> /dev/null
        fi
        if [ $ERR_CODE -ne 0 ];
        then
            echo "Error generating pdf"
        fi
    fi
done
