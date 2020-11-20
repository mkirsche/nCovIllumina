#!/bin/bash

#Run directory
OUTPUTDIR=$1
BINDIR=$2
THREADS=$3
NTCPREFIX=$4 # Empty if no NTCPREFIX

DIR=${OUTPUTDIR}/results

OUTDIR=$DIR

#SCRIPTS PATH
SCRIPT_DIR="${BINDIR}/src"

DATA="${BINDIR}/reference/pangoLEARN/data" # Update this
TMPDIR=$OUTDIR

#source /home/idies/workspace/covid19/bashrc
#conda activate pangolin
echo "Making Pangolin lineages for consensus sequences in ${DIR}"

CONS_FASTA=$OUTDIR/postfilt_consensus_all.fasta
if [ ! -f "${DIR}/$CONS_FASTA" ]; then
   ls ${DIR}/*.complete.fasta | grep -v ${NTCPREFIX} | cat - > ${CONS_FASTA}
fi

pangolin ${CONS_FASTA} -d ${DATA} -o ${OUTDIR} --outfile pangolin_lineage_report.csv --tempdir $TMPDIR -t ${THREADS}

echo "DONE"
