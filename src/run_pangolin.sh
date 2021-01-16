#!/bin/bash

# Run it in Pangolin environment
eval "$(conda shell.bash hook)"
conda activate pangolin

#Run directory
OUTPUTDIR=$1
BINDIR=$2
THREADS=$3
PANGOLIN_DATA=$4
NTCPREFIX=$5 # Empty if no NTCPREFIX

DIR=${OUTPUTDIR}/results/postfilt/

OUTDIR=${OUTPUTDIR}/results/pangolin

#SCRIPTS PATH
SCRIPT_DIR="${BINDIR}/src"

#PANGOLIN_DATA="${BINDIR}/reference/pangoLEARN/data" # Update this
TMPDIR=$OUTDIR

#source /home/idies/workspace/covid19/bashrc
#conda activate pangolin
echo "Making Pangolin lineages for consensus sequences in ${DIR}"

mkdir -p ${OUTDIR}

CONS_FASTA=$OUTDIR/postfilt_consensus_all.fasta
if [ ! -f "${DIR}/$CONS_FASTA" ]; then
   #ls ${DIR}/*.complete.fasta | grep -v ${NTCPREFIX} | cat - > ${CONS_FASTA}
   ls ${DIR}/*.complete.fasta | grep -v ${NTCPREFIX}".complete.fasta" | xargs -I % cat % > ${CONS_FASTA}
fi

pangolin ${CONS_FASTA} -d ${PANGOLIN_DATA} -o ${OUTDIR} --outfile pangolin_lineage_report.csv --tempdir $TMPDIR -t ${THREADS}

echo "PANGOLIN SCRIPT DONE"
