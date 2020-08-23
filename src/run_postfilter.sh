#!/bin/bash

## SET UP FILENAMES

# get the working directory
RUN=$1

# get the code directory
BINDIR=$2

# get known directory and file names
DIR="$RUN/results"
global_vars="$BINDIR/reference/nextstrain_ncov_global_diversity.tsv" # observed global variants
key_vars="$BINDIR/reference/key_positions.txt" # clade-definiting positions
case_defs="$BINDIR/reference/variant_case_definitions.csv" # types of variant annotations
reference="$BINDIR/reference/nCoV-2019.reference.fasta" # reference genome
amplicons="$BINDIR/reference/v3_artic_amplicons.tsv" # amplicons file

# get NTC information
NTC=$3 # this will be empty if there is no NTC

# if NTC is non-empty
if [ -n "$NTC" ]; then
	ntc_depthfile="$DIR/samtools/$NTC.mapped.primertrimmed.sorted.del.depth"
	ntc_bamfile="$DIR/ncovIllumina_sequenceAnalysis_trimPrimerSequences/$NTC.mapped.primertrimmed.sorted.bam"
else
	ntc_depthfile="None"
	ntc_bamfile="None"
fi

# make and save output directory
outdir="$DIR/postfilt"
if [ ! -d $outdir ]; then
        mkdir $outdir
fi


## RUN SAMTOOLS DEPTH ON ALL SAMPLES

# loop through all samples (includes NTC if it exists)
for consfile in $DIR/ncovIllumina_sequenceAnalysis_makeConsensus/*.consensus.fa; do

	sample=${consfile##*/}
	samplename=${sample%%.*}

	bamfile="$DIR/ncovIllumina_sequenceAnalysis_trimPrimerSequences/$samplename.mapped.primertrimmed.sorted.bam"
	outfile="$DIR/samtools/$samplename.mapped.primertrimmed.sorted.del.depth"
	chromname=$(head -1 $BINDIR/reference/nCoV-2019.reference.fasta | cut -c2-)
	
	# run script
	if [ ! -f $outfile ]; then
		echo "calculating depths for $samplename"
		python $BINDIR/src/calc_sample_depths.py $bamfile $outfile $chromname
	fi

done


## RUN POSTFILTERING ON ALL SAMPLES

# loop through all samples (skip NTC if it exists)
for consfile in $DIR/ncovIllumina_sequenceAnalysis_makeConsensus/*.consensus.fa; do

	sample=${consfile##*/}
	samplename=${sample%%.*}

	if [ ! "$samplename" = "$NTC" ]; then

		echo "running postfiltering for $samplename"

		vcffile=$DIR/merging/$samplename.all_caller_freqs.vcf
		mpileup="$DIR/samtools/$samplename.mpileup"
		depth="$DIR/samtools/$samplename.mapped.primertrimmed.sorted.del.depth"
		consensus="$DIR/ncovIllumina_sequenceAnalysis_makeConsensus/$samplename.primertrimmed.consensus.fa"

		# run script
		python $BINDIR/src/postfilter.py \
		--vcffile $vcffile \
		--mpileup $mpileup \
		--depthfile $depth \
		--consensus $consensus \
		--ntc-bamfile $ntc_bamfile \
		--ntc-depthfile $ntc_depthfile \
		--global-vars $global_vars \
		--key-vars $key_vars \
		--case-defs $case_defs \
		--ref-genome $reference \
		--amplicons $amplicons \
		--outdir $outdir \
		--prefix $samplename

	fi

done


## SUMMARIZE RESULTS AND ORGANIZE FINAL FOLDER

if [ ! -d $DIR/final ]; then
        mkdir $DIR/final
        mkdir $DIR/final/complete_genomes $DIR/final/partial_genomes
        touch $DIR/final/failed_samples.txt
        echo $NTC > $DIR/final/negative_control.txt
fi

for bam in $DIR/ncovIllumina_sequenceAnalysis_trimPrimerSequences/*.primertrimmed.sorted.bam; do
	
	sample=${bam##*/}
	samplename=${sample%%.*}

	if [ -f $DIR/postfilt/$samplename.complete.fasta ]; then
		cp $DIR/postfilt/$samplename.complete.fasta $DIR/final/complete_genomes/$samplename.fasta

	elif [ -f $DIR/postfilt/$samplename.partial.fasta ]; then
		cp $DIR/postfilt/$samplename.partial.fasta $DIR/final/partial_genomes/$samplename.fasta
	
	else
		echo $samplename >> failed_samples.txt

	fi

done

python $BINDIR/src/summarize_postfilter.py --rundir $DIR/postfilt
mv $DIR/postfilt/postfilt_all.txt $DIR/final/all_variants_annotated.txt
mv $DIR/postfilt/postfilt_summary.txt $DIR/final/run_summary.txt