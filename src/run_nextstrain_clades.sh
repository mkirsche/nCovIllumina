#!/bin/bash

#Run directory
OUTPUTDIR=$1
BINDIR=$2
NTCPREFIX=$3

DIR="${OUTPUTDIR}/results"

OUTDIR=$DIR

SCRIPT_DIR="$BINDIR/src"
REF_GB="${BINDIR}/reference/reference_seq.gb"
NEXTSTRAIN_CLADES="${BINDIR}/reference/clades.tsv"

#source /home/idies/workspace/covid19/bashrc
#conda activate nextstrain

echo "Assigning nextstrain clades for consensus sequences in ${DIR}"

CONS_FASTA=$OUTDIR/postfilt_consensus_all.fasta

if [ ! -f "${DIR}/$CONS_FASTA" ]; then
    echo " File : ${DIR}/$CONS_FASTA does not exist... Making "
    ls ${DIR}/*.complete.fasta | grep -v ${NTCPREFIX} | cat - > ${OUTDIR}/${CONS_FASTA}
fi

#usage: assign_clades.py [-h] --sequences SEQUENCES --clade CLADE --gbk GBK [--output OUTPUT] [--keep-temporary-files] [--chunk-size CHUNK_SIZE]
#                        [--nthreads NTHREADS]

${SCRIPT_DIR}/assign_clades.py --sequences ${OUTDIR}/${CONS_FASTA} --output ${OUTDIR}/nextstrain_clades.tsv --gbk ${REF_GB} --clade ${NEXTSTRAIN_CLADES}
echo "DONE"
