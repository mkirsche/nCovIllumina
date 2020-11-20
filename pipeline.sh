### Pipeline for processing Illumina reads ###

## Set up parameters

# Get run directory
if [ "$(uname -s)" = 'Linux' ]; then
    BINDIR=$(dirname "$(readlink -f "$0" || echo "$(echo "$0" | sed -e 's,\\,/,g')")")
else
    BINDIR=$(dirname "$(readlink "$0" || echo "$(echo "$0" | sed -e 's,\\,/,g')")")
fi

# Load parameters from config
source $BINDIR/config/illumina.txt

# Set up script parameters based on config setup
REFERENCE=$GENOMEDIR/$PATHOGENREF/$PRIMERVERSION/*.reference.fasta
GENES=$GENOMEDIR/$PATHOGENREF/$PRIMERVERSION/genes.gff3

# postfiltering parameters
GLOBALDIVERSITY=$GENOMEDIR/$PATHOGENREF/$PRIMERVERSION/approx_global_diversity.tsv # observed global variants
KEYPOS=$GENOMEDIR/$PATHOGENREF/$PRIMERVERSION/key_positions.txt # clade-definiting positions
CASEDEFS=$GENOMEDIR/$PATHOGENREF/$PRIMERVERSION/variant_case_definitions.csv # types of variant annotations
AMPLICONS=$GENOMEDIR/$PATHOGENREF/$PRIMERVERSION/amplicons.tsv # amplicons file

REF_GB=$GENOMEDIR/$PATHOGENREF/$PRIMERVERSION/reference_seq.gb
PANGOLIN_DATA=$GENOMEDIR/$PATHOGENREF/$PRIMERVERSION/pangoLEARN/data
NEXTSTRAIN_CLADES=$GENOMEDIR/$PATHOGENREF/$PRIMERVERSION/clades.tsv
SNPEFF_CONFIG=$GENOMEDIR/$PATHOGENREF/$PRIMERVERSION/snpEff.config

# Get input and output directories
if [ "$#" -eq 2 ]
then
    INPUTDIR=$1
    OUTPUTDIR=$2
fi

cd $OUTPUTDIR


## Load submodule
if [ ! -r $BINDIR/VariantValidator/README.md ]
then
  echo 'Downloading VariantValidator submodule'
  cd $BINDIR
  git submodule update --init --recursive
  cd $OUTPUTDIR
fi

javac $BINDIR/VariantValidator/src/*.java

#------------------------------------------------------------------------------

## Filter reads by length
FILTEREDINPUTDIR=$OUTPUTDIR'/filteredreads'
$BINDIR/src/filterreads.sh $INPUTDIR $FILTEREDINPUTDIR $BINDIR $MIN_READ_LENGTH $MAX_READ_LENGTH

#------------------------------------------------------------------------------

# Run iVar pipeline
if [ ! -d $OUTPUTDIR/results ]
then
  echo 'Getting ivar config'
  javac $BINDIR/src/ParseIvarConfig.java
  extraargs=`java -cp $BINDIR/src ParseIvarConfig $BINDIR/config/illumina.txt`
  echo 'Running ivar'
  $BINDIR/src/ivar.sh $FILTEREDINPUTDIR $extraargs
fi

#------------------------------------------------------------------------------

## Call variants 

# Load necessary conda environment
source /home/idies/workspace/covid19/code/nCovIllumina/bashrc
conda activate ncov_illumina

# Call variants
$BINDIR/src/callvariants.sh $OUTPUTDIR $BINDIR $REFERENCE $GENES

#------------------------------------------------------------------------------

## Run postfiltering
$BINDIR/src/run_postfilter.sh $OUTPUTDIR $BINDIR $NTCPREFIX $REFERENCE $GLOBALDIVERSITY $KEYPOS $CASEDEFS $AMPLICONS
# run postfilter summary
python $BINDIR/src/summarize_postfilter.py --rundir $OUTPUTDIR/results/postfilt

#------------------------------------------------------------------------------

## Run SnpEff
$BINDIR/src/run_snpEff.sh $OUTPUTDIR $BINDIR $SNPEFF_CONFIG $DBNAME $NTCPREFIX

#------------------------------------------------------------------------------

## Run pangolin clades

if [ -z $THREADS ]; then
   THREADS=1
fi
conda deactivate
conda activate pangolin
$BINDIR/src/run_pangolin.sh $OUTPUTDIR $BINDIR $THREADS $PANGOLIN_DATA $NTCPREFIX

#------------------------------------------------------------------------------

## Run nextstrain clades 
conda deactivate
conda activate nextstrain
$BINDIR/src/run_nextstrain_clades.sh $OUTPUTDIR $BINDIR $REF_GB $NEXTSTRAIN_CLADES $NTCPREFIX

#------------------------------------------------------------------------------

## Copy final results into final folder
$BINDIR/src/final_cleanup.sh $OUTPUTDIR $NTCPREFIX
