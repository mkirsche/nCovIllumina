### Script to move final out-facing data into one directory

OUTPUTDIR=$1
BINDIR=$2
NTCPREFIX=$3

# Set up sub-directory in which to store final results
if [ ! -d $OUTPUTDIR/final_results ]; then
        mkdir $OUTPUTDIR/final_results
        mkdir $OUTPUTDIR/final_results/complete_genomes $OUTPUTDIR/final_results/partial_genomes
        touch $OUTPUTDIR/final_results/failed_samples.txt
        echo $NTCPREFIX > $OUTPUTDIR/final_results/negative_control.txt
fi


# Copy final genomes into final results folder
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

# Summarize variants and copy into final results folder
python $BINDIR/summarize_postfilter.py --rundir $OUTPUTDIR/results/postfilt/ --annot $OUTPUTDIR/results/snpEff/final_snpEff_report.txt
cp $OUTPUTDIR/results/postfilt/postfilt_all.txt $OUTPUTDIR/final_results/all_variants.txt
cp $OUTPUTDIR/results/postfilt/postfilt_all_annot.txt $OUTPUTDIR/final_results/all_variants_annotated.txt
cp $OUTPUTDIR/results/postfilt/postfilt_all_annot_consensus.txt $OUTPUTDIR/final_results/all_consensus_variants_annotated.txt