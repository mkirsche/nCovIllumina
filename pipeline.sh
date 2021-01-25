#!/bin/bash

### Pipeline for processing Illumina reads ###

## Set up parameters

# Get run directory
if [ "$(uname -s)" = 'Linux' ]; then
    BINDIR=$(dirname "$(readlink -f "$0" || echo "$(echo "$0" | sed -e 's,\\,/,g')")")
else
    BINDIR=$(dirname "$(readlink "$0" || echo "$(echo "$0" | sed -e 's,\\,/,g')")")
fi

#------------------------------------------------------------------------------

usage()
{
cat << EOF
usage: $0 [options]

OPTIONS:
   -h      show this message
   -i      path to input folder containing FASTQs
   -o      path to folder where output 'results' folder will be placed
   -c      path to config file for this run

EOF
}

#------------------------------------------------------------------------------
# set default values here
CONFIG=/opt/nCovIllumina/config/illumina.txt

# parse input arguments
while getopts "hi:o:c:" OPTION
do
	case $OPTION in
		h) usage; exit 1 ;;
		i) INPUTDIR=$OPTARG ;;
		o) OUTPUTDIR=$OPTARG ;;
		c) CONFIG=$OPTARG ;;
		?) usage; exit ;;
	esac
done

# if necessary arguments are not present, display usage info and exit
if [[ ! -s "$BINDIR/bashrc" ]]; then
	echo "Error: BINDIR ($BINDIR) does not contain the expected bashrc file."
	usage
	exit 2
fi

# if necessary arguments are not present, display usage info and exit
if [[ -z "$OUTPUTDIR" ]]; then
	OUTPUTDIR="$INPUTDIR"
fi

#------------------------------------------------------------------------------

# Load parameters from config
source "$BINDIR/bashrc"

# Set up script parameters based on config setup
REFERENCE=$GENOMEDIR/$PATHOGENREF/$PRIMERVERSION/*.reference.fasta
GENES=$GENOMEDIR/$PATHOGENREF/$PRIMERVERSION/genes.gff3

# postfiltering parameters
GLOBALDIVERSITY=$GENOMEDIR/$PATHOGENREF/$PRIMERVERSION/approx_global_diversity.tsv # observed global variants
KEYPOS=$GENOMEDIR/$PATHOGENREF/$PRIMERVERSION/key_positions.txt # clade-definiting positions
CASEDEFS=$GENOMEDIR/$PATHOGENREF/$PRIMERVERSION/variant_case_definitions.csv # types of variant annotations
AMPLICONS=$GENOMEDIR/$PATHOGENREF/$PRIMERVERSION/amplicons.tsv # amplicons file
HOMOPOLYMERS=$GENOMEDIR/$PATHOGENREF/$PRIMERVERSION/homopolymer_positions.txt # homopolymer positions

REF_GB=$GENOMEDIR/$PATHOGENREF/$PRIMERVERSION/reference_seq.gb
PANGOLIN_DATA=$GENOMEDIR/$PATHOGENREF/$PRIMERVERSION/pangoLEARN/pangoLEARN/data
NEXTSTRAIN_CLADES=$GENOMEDIR/$PATHOGENREF/$PRIMERVERSION/clades.tsv
SNPEFF_CONFIG=$GENOMEDIR/$PATHOGENREF/$PRIMERVERSION/snpEff/snpEff.config

cd "$OUTPUTDIR"
source "$CONFIG"

## Load submodule
if [ ! -r "$BINDIR/VariantValidator/README.md" ]
then
  echo 'Downloading VariantValidator submodule'
  cd "$BINDIR"
  git submodule update --init --recursive
  cd "$OUTPUTDIR"
fi

javac $BINDIR/VariantValidator/src/*.java

#------------------------------------------------------------------------------

## Filter reads by length
FILTEREDINPUTDIR=$OUTPUTDIR'/filteredreads'
if [ ! -r "$FILTEREDINPUTDIR" ]; then
  $BINDIR/src/filterreads.sh $INPUTDIR $FILTEREDINPUTDIR $BINDIR $MIN_READ_LENGTH $MAX_READ_LENGTH
fi

echo "---------------------------------"
echo "READ FILTERING COMPLETE"
echo "---------------------------------"

#------------------------------------------------------------------------------

## Run iVar pipeline
if [ ! -d "$OUTPUTDIR/results" ]; then
  mkdir "$OUTPUTDIR/results"
  cp "$CONFIG" "$OUTPUTDIR/results"
  echo 'Getting ivar config'
  javac $BINDIR/src/ParseIvarConfig.java
  extraargs=`java -cp $BINDIR/src ParseIvarConfig $CONFIG`
  echo 'Running ivar'
  conda activate artic-ncov2019-illumina
  $BINDIR/src/ivar.sh $FILTEREDINPUTDIR $extraargs
fi

echo "---------------------------------"
echo "IVAR PIPELINE COMPLETE"
echo "---------------------------------"

#------------------------------------------------------------------------------

## Call variants 

# Load necessary conda environment
conda activate ncov_illumina

# Call variants
if [ ! -d "$OUTPUTDIR/results/merging" ]; then
  $BINDIR/src/callvariants.sh $OUTPUTDIR $BINDIR $REFERENCE $GENES
fi

echo "---------------------------------"
echo "VARIANT CALLING AND MERGING COMPLETE"
echo "---------------------------------"

#------------------------------------------------------------------------------

## Run postfiltering

# postfilter run script runs only necessary portions of pipeline
$BINDIR/src/run_postfilter.sh $OUTPUTDIR $BINDIR $NTCPREFIX $REFERENCE $GLOBALDIVERSITY $KEYPOS $CASEDEFS $AMPLICONS $HOMOPOLYMERS

# run postfilter summary
#python $BINDIR/src/summarize_postfilter.py --rundir $OUTPUTDIR/results/postfilt

echo "---------------------------------"
echo "POST-FILTERING COMPLETE"
echo "---------------------------------"

#------------------------------------------------------------------------------

## Run SnpEff
if [ ! -d "$OUTPUTDIR/results/snpeff" ]; then
  $BINDIR/src/run_snpEff.sh $OUTPUTDIR $BINDIR $SNPEFF_CONFIG $NTCPREFIX
fi

echo "---------------------------------"
echo "SNPEFF VARIANT ANNOTATION COMPLETE"
echo "---------------------------------"

#------------------------------------------------------------------------------

## Run pangolin clades

if [ -z $THREADS ]; then
   THREADS=1
fi

# pangolin-specific conda environment loaded in pangolin script
conda deactivate

# run pangolin
if [ ! -d "$OUTPUTDIR/results/pangolin" ]; then
  $BINDIR/src/run_pangolin.sh $OUTPUTDIR $BINDIR $THREADS $PANGOLIN_DATA $NTCPREFIX
fi

echo "---------------------------------"
echo "PANGOLIN CLADE ASSIGNMENT COMPLETE"
echo "---------------------------------"

#------------------------------------------------------------------------------

## Run nextstrain clades 

# next-strain specific conda environment loaded in nextstrain script
conda deactivate

if [! -d "$OUTPUTDIR/results/nextstrain "]; then
  $BINDIR/src/run_nextstrain_clades.sh $OUTPUTDIR $BINDIR $REF_GB $NEXTSTRAIN_CLADES $NTCPREFIX
fi

echo "---------------------------------"
echo "NEXTSTRAIN CLADE ASSIGNMENT COMPLETE"
echo "---------------------------------"

#------------------------------------------------------------------------------

## Copy final results into final folder
$BINDIR/src/final_cleanup.sh $OUTPUTDIR $NTCPREFIX
