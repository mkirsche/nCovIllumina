#!/bin/bash

# Run it in nextstrain env
eval "$(conda shell.bash hook)"
conda activate ncov_illumina


#Run directory
OUTPUTDIR=$1
BINDIR=$2
META_CONF=$3
PANGOLIN_TSV=$4
NEXTSTRAIN_TSV=$5
GLOBAL_SEQ=$6
GLOBAL_META=$7
RUN_NAME=$8

OUTDIR=${OUTPUTDIR}/results/nextstrain

SCRIPT_DIR="$BINDIR/src"

mkdir -p ${OUTDIR}

CONS_FASTA=$OUTDIR/postfilt_consensus_all.fasta

if [ ! -f "$CONS_FASTA" ]; then
    echo " File : $CONS_FASTA does not exist..."
    echo "Run Nextstrian clades and pangolin clade script before runnning this script"
    exit 1  
fi

${SCRIPT_DIR}/prepare_nextstrain_alpha.py -g ${CONS_FASTA} --metadata-config ${META_CONF} --pangolin_clade ${PANGOLIN_TSV} --nextstrain_clade ${NEXTSTRAIN_TSV} -out ${OUTDIR} --global-meta ${GLOBAL_META} --global-seq ${GLOBAL_SEQ} --run_name ${RUN_NAME}

conda deactivate
conda activate nextstrain

# Run Snakemake pipeline
cd ${SCRIPT_DIR}/../nextstrain_JHU
snakemake --cores 4 --profile ${OUTDIR}/custom_profile -s Snakefile_local
cd -
echo "NEXTSTRAIN ALPHA COMPLETED DONE"
