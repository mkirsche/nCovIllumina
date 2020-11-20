#!/bin/bash

#TODO:
# 1 ) Autogenerate snpEff config to be able to run for genomes other than COVID19
# 2 ) Autobuild SnpEff db if not present

#Run directory
OUTPUTDIR=$1

#Get the code directory
BINDIR=$2

SNPEFF_CONFIG=$3
DBNAME=$4
NTCPREFIX=$5

DIR="${OUTPUTDIR}/results"   
OUTDIR=$DIR

#SNPEFF_CONFIG="${BINDIR}/reference/snpEff.config"
#DBNAME="ncov"

SCRIPT_DIR="${BINDIR}/src"
for vcf in $DIR/*.allcallers_combined.vcf; do
    ${SCRIPT_DIR}/annotate_variants.sh ${vcf} ${SNPEFF_CONFIG} ${DBNAME} ${OUTDIR}
    echo "SnpEff completed on run ${DIR}"
done

echo "Making final reports on run ${DIR}"
ls ${OUTDIR}/*_ann_report.txt |  grep -v ${NTCPREFIX} | cat - | awk '$4 != "N" { print $0}'  | awk '!seen[$0]++' > ${OUTDIR}/final_snpEff_report.txt
ls ${OUTDIR}/*_ann_report.txt |  grep -v ${NTCPREFIX} | cat - | awk '!seen[$0]++' | awk 'NR == 1  || $4 == "N" { print $0}'  > ${OUTDIR}/snpEff_report_with_Ns.txt
echo "DONE"
