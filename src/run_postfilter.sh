#!/bin/bash

## SET UP FILENAMES

# get the output directory
OUTPUTDIR=$1
DIR=$OUTPUTDIR/results

# get the code directory
BINDIR=$2

# get NTC information
NTC=$3 # this will be empty if there is no NTC

# get other parameters
REFERENCE=$4
GLOBALDIVERSITY=$5
KEYPOS=$6
CASEDEFS=$7
AMPLICONS=$8

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
	chromname=$(head -1 $REFERENCE | cut -c2-)
	
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
		--global-vars $GLOBALDIVERSITY \
		--key-vars $KEYPOS \
		--case-defs $CASEDEFS \
		--ref-genome $REFERENCE \
		--amplicons $AMPLICONS \
		--outdir $outdir \
		--prefix $samplename

	fi

done