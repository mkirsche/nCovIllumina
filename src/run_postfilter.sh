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
HOMOPOLYMERS=$9
chromname=$(head -1 $REFERENCE | cut -c2-)

# if NTC is non-empty
if [ -n "$NTC" ]; then
	ntc_depthfile="$DIR/samtools/$NTC.mapped.primertrimmed.sorted.del.depth"
	ntc_bamfile="$DIR/ncovIllumina_sequenceAnalysis_trimPrimerSequences/$NTC.mapped.primertrimmed.sorted.bam"
	if [ ! -f $ntc_depthfile ]; then
		echo "calculating depths for NTC"
		python $BINDIR/src/calc_sample_depths.py $ntc_bamfile $ntc_depthfile $chromname
	fi
else
	ntc_depthfile="None"
	ntc_bamfile="None"
fi

# make and save output directory
outdir="$DIR/postfilt"
if [ ! -d $outdir ]; then
        mkdir $outdir
fi


## RUN POSTFILTERING

# loop through all samples except NTC
for consfile in $DIR/ncovIllumina_sequenceAnalysis_makeConsensus/*.consensus.fa; do

	# get sample name
	sample=${consfile##*/}
	samplename=${sample%%.*}

	if [ ! "$samplename" = "$NTC" ]; then

		# find relevant files
		bamfile="$DIR/ncovIllumina_sequenceAnalysis_trimPrimerSequences/$samplename.mapped.primertrimmed.sorted.bam"
		depthfile="$DIR/samtools/$samplename.mapped.primertrimmed.sorted.del.depth"
		chromname=$(head -1 $REFERENCE | cut -c2-)
		
		# RUN SAMTOOLS DEPTH (all samples including NTC)
		if [ ! -f $depthfile ]; then
			echo "calculating depths for $samplename"
			python $BINDIR/src/calc_sample_depths.py $bamfile $depthfile $chromname
		fi
 
		# ALIGN SAMPLE TO REFERENCE GENOME
		if [ ! -f $outdir/$samplename.align.ref.fasta ]; then

			echo "aligning $samplename to reference genome"
			cat $REFERENCE $consfile > "$outdir/$samplename.ref.fasta" # reference must be first
			mafft --preservecase "$outdir/$samplename.ref.fasta" > "$outdir/$samplename.align.ref.fasta"

		fi

		# RUN POSTFILTERING CODE
		if [ ! -f $outdir/$samplename.variant_data.txt ]; then

			echo "running postfiltering for $samplename"

			vcffile=$DIR/merging/$samplename.all_caller_freqs.vcf
			consensus="$DIR/ncovIllumina_sequenceAnalysis_makeConsensus/$samplename.primertrimmed.consensus.fa"
			alignment="$DIR/postfilt/$samplename.align.ref.fasta"

			# run script
			python $BINDIR/src/pf_working.py \
			--vcffile $vcffile \
			--depthfile $depthfile \
			--aln-to-ref $alignment \
			--ntc-bamfile $ntc_bamfile \
			--ntc-depthfile $ntc_depthfile \
			--global-vars $GLOBALDIVERSITY \
			--key-vars $KEYPOS \
			--homopolymers $HOMOPOLYMERS \
			--case-defs $CASEDEFS \
			--amplicons $AMPLICONS \
			--outdir $outdir \
			--samplename $samplename
		fi
	fi

	echo "all parts complete for $samplename"

done