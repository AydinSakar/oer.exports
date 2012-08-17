#!/bin/sh

# This script is used to generate mobi file from a unzipped collection.
# 

# 1st arg is the path to the collection
# 2nd arg is the name of the mobi file
# 3rd arg is the css file eg:ccap-physics 

WORKING_DIR=$1
OUTPUT=$2
CSS_FILE=$3

ROOT=$(dirname "$0")
ROOT=$(cd "$ROOT/.."; pwd) 
CWD=$(pwd)

KINDLEGEN=$(which kindlegen)
PHANTOMJS=$(which phantomjs)

XHTML_FILE=$WORKING_DIR/"$OUTPUT.xhtml"
HTML_FILE=$WORKING_DIR/"$OUTPUT.html"
MOBI_FILE="$OUTPUT.mobi"
EXIT_STATUS=0

#DEBUG=false
DEBUG=true

cd ${ROOT}

if [ -s $WORKING_DIR/collection.xml ]; then

  echo "P1: Building xhtml content and opf file..."
  python cm.py -d ${WORKING_DIR} -o ${XHTML_FILE} #2>/dev/null
  EXIT_STATUS=$EXIT_STATUS || $?

  #Modify the opf file to add cover and "toc" entry...
  echo "P2: Modifing opf..."
  ./scripts/opf-modifier.sh "$OUTPUT.html" ${WORKING_DIR}
  EXIT_STATUS=$EXIT_STATUS || $?

  echo "P3: Styling xhtml..."
  ${PHANTOMJS} epubcss/phantom-harness.coffee css/${CSS_FILE} ${ROOT}/${XHTML_FILE} ./${HTML_FILE} ./output.css
  EXIT_STATUS=$EXIT_STATUS || $?

  echo "P4: Coverting transparent png to non-transparent png..."
  ./scripts/convertpng.sh ${WORKING_DIR}
  EXIT_STATUS=$EXIT_STATUS || $?

  #Replace <p>,</p> in listitem/abstract to <a>,</a>
  echo "P5: Replacing <p></p>..."
  sed -i -f scripts/tagp2a-listitem.sed ${HTML_FILE}
  sed -i -f scripts/tagp2a-abstract.sed ${HTML_FILE}

  #Insert pagebreaks between chapters,before toc and other sections
  echo "P6: Inserting pagebreaks..."
  sed -i 's/\(<h1 class="title autogen\)/<mbp:pagebreak \/>\1/g' ${HTML_FILE}
  sed -i 's/\(<h2 class="title autogen\)/<mbp:pagebreak \/>\1/g' ${HTML_FILE}
  sed -i 's/\(<h3 class="title autogen\)/<mbp:pagebreak \/>\1/g' ${HTML_FILE}
  sed -i 's/\(<div class="titlepage autogen\)/<mbp:pagebreak \/>\1/g' ${HTML_FILE}
  sed -i 's/\(Table of Contents\)/<mbp:pagebreak \/><h3>\1<\/h3>/' ${HTML_FILE}
  #sed -i '/class="colophon"/i<mbp:pagebreak \/>' ${HTML_FILE}
  #sed -i '/\(<div class="colophon autogen-\)/<mbp:pagebreak \/>\1' ${HTML_FILE}
  #sed -i '/class="toc"/i<mbp:pagebreak \/>' ${HTML_FILE}
  #sed -i "s/title>\(.*\)<\/title/title>\1-${OUTPUT}<\/title/" ${HTML_FILE}
  #sed -i '/class="titlepage"/i<mbp:pagebreak \/>' ${HTML_FILE}
  #sed -i 's/\(<h1 class="title autogen-\)/<mbp:pagebreak \/>\1/' ${HTML_FILE}
  #sed -i 's/\(<div class="titlepage\)/<mbp:pagebreak \/>\1/' ${HTML_FILE}
  #sed -i 's/\(<div class="title \)/<mbp:pagebreak \/>\1/' ${HTML_FILE}

  #Insert the toc mark,only to the first match(because there are othere tocs)
  echo "P5: Inserting toc mark..."
  #sed -i '1,/<div class="toc">/s/<div class="toc">/<a name="toc"\/><div class="toc">/' ${HTML_FILE}
  sed -i '1,/<div class="toc/s/\(<div class="toc\)/<a name="toc"\/>\1/' ${HTML_FILE}

  #In the ccap-sociology.css, there are some '.' in the example-section generated by css which are 
  #not necessary, delete them here.
  #e.g.:"Example  1.1 .  Calculating intensity and power: How much energy is in a ray of sunlight?"
  if [ ${CSS_FILE} = "ccap-sociology.css" ];then
    echo "Special: Sociology-example '.'-fix..."
    sed -i '/cnx-gentext-example cnx-gentext-autogenerated">\./d' ${HTML_FILE}
  fi

  #Build the mobi from the .opf file
  echo "P7: Generating .mobi..."
  ${KINDLEGEN} ${WORKING_DIR}/content.opf -o ${MOBI_FILE} 1>&2 #-verbose
  EXIT_STATUS=$EXIT_STATUS || $?

  if [ -s ${WORKING_DIR}/${MOBI_FILE} ];then
    echo "END: MOBI built succiessfully."
  fi

  if ! $DEBUG; then
    rm ${XHTML_FILE}
    rm ${HTML_FILE}
    rm ${WORKING_DIR}/content.opf
    rm ./output.css
  fi

  cd ${CWD}

  if [ $EXIT_STATUS -ne 0 ];then
    echo "ERROR OCCURS." 1>&2
    exit 1
  fi
  
else
  echo "ERROR: The first argument does not point to a directory containing a 'index.cnxml' or 'collection.xml' file" 1>&2
  exit 1
fi
exit $EXIT_STATUS
