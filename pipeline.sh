# Pipeline for processing Illumina reads
if [ "$(uname -s)" = 'Linux' ]; then
    BINDIR=$(dirname "$(readlink -f "$0" || echo "$(echo "$0" | sed -e 's,\\,/,g')")")
else
    BINDIR=$(dirname "$(readlink "$0" || echo "$(echo "$0" | sed -e 's,\\,/,g')")")
fi

source $BINDIR/config/illumina.txt

if [ "$#" -eq 2 ]
then
    INPUTDIR=$1
    OUTPUTDIR=$2
fi

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

# Set up sub-directory in which to store final results
if [ ! -d $OUTPUTDIR/final_results ]; then
        mkdir $OUTPUTDIR/final_results
        mkdir $OUTPUTDIR/final_results/complete_genomes $OUTPUTDIR/final_results/partial_genomes
        touch $OUTPUTDIR/final_results/failed_samples.txt
        echo $NTCPREFIX > $OUTPUTDIR/final_results/negative_control.txt
fi

# Call variants
$BINDIR/callvariants.sh $OUTPUTDIR $BINDIR $REFERENCE $GENES

# Run postfiltering
$BINDIR/src/run_postfilter.sh $OUTPUTDIR $BINDIR $NTCPREFIX

# Copy postfiltering results into final results folder
for bam in $OUTPUTDIR/results/ncovIllumina_sequenceAnalysis_trimPrimerSequences/*.primertrimmed.sorted.bam; do
  
  sample=${bam##*/}
  samplename=${sample%%.*}

  if [ ! "$samplename" = "$NTCPREFIX" ]; then

    if [ -f $OUTPUTDIR/results/postfilt/$samplename.complete.fasta ]; then
      cp $OUTPUTDIR/results/postfilt/$samplename.complete.fasta $OUTPUTDIR/final_results/complete_genomes/$samplename.fasta

    elif [ -f $OUTPUTDIR/results/postfilt/$samplename.partial.fasta ]; then
      cp $OUTPUTDIR/results/postfilt/$samplename.partial.fasta $OUTPUTDIR/final_results/partial_genomes/$samplename.fasta
    
    else
      echo $samplename >> $OUTPUTDIR/final_results/failed_samples.txt

    fi

  fi

done

mv $OUTPUTDIR/results/postfilt/postfilt_all.txt $OUTPUTDIR/final_results/all_variants_annotated.txt
mv $OUTPUTDIR/results/postfilt/postfilt_summary.txt $OUTPUTDIR/final_results/run_summary.txt
