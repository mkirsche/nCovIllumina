#!/bin/bash


# Run it in nextstrain env

#Run directory
OUTPUTDIR=$1
BINDIR=$2
REF_GB=$3
NEXTSTRAIN_CLADES=$4
NTCPREFIX=$5

DIR="${OUTPUTDIR}/results/postfilt/"

OUTDIR=${OUTPUTDIR}/results/nextstrain

SCRIPT_DIR="$BINDIR/src"

echo "Assigning nextstrain clades for consensus sequences in ${DIR}"

mkdir -p ${OUTDIR}

CONS_FASTA=$OUTDIR/postfilt_consensus_all.fasta

if [ ! -f "${DIR}/$CONS_FASTA" ]; then
    echo " File : ${DIR}/$CONS_FASTA does not exist... Making "
    #ls ${DIR}/*.complete.fasta | grep -v ${NTCPREFIX} | cat - > ${OUTDIR}/${CONS_FASTA}
    ls ${DIR}/*.complete.fasta | grep -v ${NTCPREFIX}".complete.fasta" | xargs -I % cat % > ${CONS_FASTA}
fi

#usage: assign_clades.py [-h] --sequences SEQUENCES --clade CLADE --gbk GBK [--output OUTPUT] [--keep-temporary-files] [--chunk-size CHUNK_SIZE]
#                        [--nthreads NTHREADS]

${SCRIPT_DIR}/assign_clades.py --sequences ${CONS_FASTA} --output ${OUTDIR}/nextstrain_clades.tsv --gbk ${REF_GB} --clade ${NEXTSTRAIN_CLADES}
echo "DONE"
