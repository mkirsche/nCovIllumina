#!/usr/bin/env bash

set -eo pipefail

eval "$(conda shell.bash hook)"
conda activate ncov_illumina

#TODO:
# 1 ) Autogenerate snpEff config to be able to run for genomes other than COVID19
# 2 ) Autobuild SnpEff db if not present

#Run directory
OUTPUTDIR=$1

#Get the code directory
BINDIR=$2

SNPEFF_CONFIG=$3
NTCPREFIX=$4

DIR="${OUTPUTDIR}/results/merging"   
OUTDIR=${OUTPUTDIR}/results/snpEff

# get the database name from the snpeff config file
DBNAME=$(head -n 1 $SNPEFF_CONFIG | cut -d':' -f2 | cut -c2-)

if [ ! -d "$OUTDIR" ]; then
	mkdir -p ${OUTDIR}
fi

if ! [ -x "$(command -v snpEff)" ]; then
  echo 'Error: snpEff is not installed in ${PATH} ' >&2
  exit 1
fi
 
for VCF in $DIR/*.allcallers_combined.vcf; do

	VCF_BASE=$( basename ${VCF} ".vcf")
	CONFIG_DIR=$( dirname ${SNPEFF_CONFIG} )
	CONFIG_DATA=${CONFIG_DIR}
	AA_DATA=${CONFIG_DIR}/amino_acid_codes.txt

	echo "running snpEff for $VCF_BASE"

	# run snpeff annotation
	snpEff eff -c ${SNPEFF_CONFIG} -dataDir ${CONFIG_DATA} ${DBNAME} ${VCF} > ${OUTDIR}/${VCF_BASE}_ann.vcf

	# make snpeff report
	# Report of all 3 letter amino acide codes
	awk -F $'\t' '/^#/ { if ( $1 == "#CHROM" ) { new_fields="GENE\tANN\tAA_MUT" ; OFS="\t"; print $0"\t"new_fields ; next } ; print ; next } {
		n = split($8, a, ",");
		AA_MUT = "";
		for(i=1; i<=n; i++) {
			m = split(a[i], b, "|");
			if(AA_MUT == "") {
				GENE = b[4];
				ANN = b[2];
			}
			if(substr(b[11], 1, 2) == "p.") {
				if(AA_MUT != "") {
					if(AA_MUT != b[11]) {
						AA_MUT = gensub(/([A-Za-z]+[0-9]+)[\*A-Za-z]+/, "\\1X", "g", AA_MUT);
						ANN = "ambiguous";
					}
				} else {
					AA_MUT = gensub(/p\.(.*)/, "\\1", "g", b[11]);
					GENE = b[4];
					ANN = b[2];
				}
			}
		}
		printf("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", $1, $2, $3, $4, $5, $6, $7, ".", GENE, ANN, AA_MUT);
	}' "${OUTDIR}/${VCF_BASE}_ann.vcf" > "${OUTDIR}/${VCF_BASE}_ann_3letter_code.vcf"

	# Report of all clean vcf
	awk '/^#/ { if ( $1 == "#CHROM" ) { OFS="\t" ; print } else { print }}' ${OUTDIR}/${VCF_BASE}_ann_3letter_code.vcf > ${OUTDIR}/${VCF_BASE}_ann_clean.vcf 


	### Modify this for all mutations
	awk 'NR==FNR { a[$2] = $3 ; next } { FS="\t" ; if ( !/^#/ ) {  OFS="\t" ; last=$NF; gsub(/[0-9]*/,"",last) ; for(j=1;j<length(last);j+=3) { k=substr(last,j,3) ; gsub(k,a[k],$NF) } ; print }}' ${AA_DATA} ${OUTDIR}/${VCF_BASE}_ann_3letter_code.vcf >> ${OUTDIR}/${VCF_BASE}_ann_clean.vcf

	# Tab demilited report
	echo -e "#CHROM\tPOS\tREF\tALT\tGENE\tANN\tAA_MUT"  > ${OUTDIR}/${VCF_BASE}_ann_report.txt 
	awk '!/^#/{ print $1"\t"$2"\t"$4"\t"$5"\t"$9"\t"$10"\t"$11}' ${OUTDIR}/${VCF_BASE}_ann_clean.vcf >> ${OUTDIR}/${VCF_BASE}_ann_report.txt 

done

echo "Making final reports for samples in ${OUTDIR}"

ls ${OUTDIR}/*_ann_report.txt |  grep -v ${NTCPREFIX}*ann_report.txt | xargs -I % cat % | awk '$4 != "N" { print $0}'  | awk '!seen[$0]++' > ${OUTDIR}/final_snpEff_report.txt
ls ${OUTDIR}/*_ann_report.txt |  grep -v ${NTCPREFIX}*ann_report.txt | xargs -I % cat % | awk '!seen[$0]++' | awk 'NR == 1  || $4 == "N" { print $0}'  > ${OUTDIR}/snpEff_report_with_Ns.txt
