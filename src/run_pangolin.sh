#!/bin/bash

#Run directory
RUN=$1

BINDIR=$2

NTC=$3 # Empty if no NTC

DIR=${RUN}/results

OUTDIR=$DIR

#SCRIPTS PATH
SCRIPT_DIR="${BINDIR}/src"

DATA="${BINDIR}/reference/pangoLEARN/data" # Update this
TMPDIR=$OUTDIR

#source /home/idies/workspace/covid19/bashrc
#conda activate pangolin
echo "Making Pangolin lineages for consensus sequences in ${DIR}"
ls ${DIR}/*.complete.fasta | grep -v ${NTC} | cat - > $OUTDIR/postfilt_consensus_all.fasta
pangolin $OUTDIR/postfilt_consensus_all.fasta -f -d ${DATA} -o ${OUTDIR} --tempdir $TMPDIR
echo "DONE"
