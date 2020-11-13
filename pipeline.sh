# Pipeline for processing Illumina reads
if [ "$(uname -s)" = 'Linux' ]; then
    BINDIR=$(dirname "$(readlink -f "$0" || echo "$(echo "$0" | sed -e 's,\\,/,g')")")
else
    BINDIR=$(dirname "$(readlink "$0" || echo "$(echo "$0" | sed -e 's,\\,/,g')")")
fi

source $BINDIR/config/illumina.txt
cd $OUPUTDIR

if [ ! -r $BINDIR/VariantValidator/README.md ]
then
  echo 'Downloading VariantValidator submodule'
  cd $BINDIR
  git submodule update --init --recursive
  cd $OUTPUTDIR
fi

javac $BINDIR/VariantValidator/src/*.java

# Filter reads by length
FILTEREDINPUTDIR=$OUTPUTDIR'/filteredreads'
$BINDIR/filterreads.sh $INPUTDIR $FILTEREDINPUTDIR $BINDIR $MIN_READ_LENGTH $MAX_READ_LENGTH

if [ ! -d $OUTPUTDIR/results ]
then
  echo 'Getting ivar config'
  javac $BINDIR/ParseIvarConfig.java
  extraargs=`java -cp $BINDIR ParseIvarConfig $BINDIR/config/illumina.txt`
  echo 'Running ivar'
  $BINDIR/ivar.sh $FILTEREDINPUTDIR $extraargs
fi

source /home/idies/workspace/covid19/code/nCovIllumina/bashrc
conda activate ncov_illumina

# Call variants
$BINDIR/callvariants.sh $OUTPUTDIR $BINDIR $REFERENCE $GENES

$BINDIR/src/run_postfilter.sh $WORKINGDIR $BINDIR $NTCPREFIX
