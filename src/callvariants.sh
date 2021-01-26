OUTPUTDIR=$1
BINDIR=$2
REFERENCE=$3
GENES=$4

# Set up output directories for freebayes, samtools, and merging
FREEBAYESDIR=$OUTPUTDIR/results/freebayes
if [ ! -d $FREEBAYESDIR ]
then
  mkdir $FREEBAYESDIR
fi

SAMTOOLSDIR=$OUTPUTDIR/results/samtools
if [ ! -d $SAMTOOLSDIR ]
then
  mkdir $SAMTOOLSDIR
fi

MERGINGDIR=$OUTPUTDIR/results/merging
if [ ! -d $MERGINGDIR ]
then
  mkdir $MERGINGDIR
fi

# Iterate over BAM files and run variant calling pipeline for each
for bamfile in `ls $OUTPUTDIR/results/ncovIllumina_sequenceAnalysis_trimPrimerSequences/*.primertrimmed.sorted.bam`
do
  basename=`basename $bamfile`
  prefix=${basename%%.*}
  echo 'Processing '$prefix

  # Convert iVar TSV to VCF
  ivartsv=$OUTPUTDIR/results/ncovIllumina_sequenceAnalysis_callVariants/$prefix.variants.tsv
  ivarvcf=${ivartsv%.*}.vcf

  echo 'Coverting iVar to VCF: '$ivarvcf
  java -cp $BINDIR/VariantValidator/src IvarToVcf table_file=$ivartsv out_file=$ivarvcf
  
  # Index BAM filefor freebayes
  if [ ! -r $bamfile.bai ]
  then
    samtools index $bamfile
  fi

  # Call and filter freebayes variants
  if [ ! -r "$FREEBAYESDIR/$prefix.vcf" ]; then
    freebayesunfiltered=$FREEBAYESDIR/$prefix.unfiltered.vcf
    echo 'Calling freebayes variants: ' $freebayesunfiltered
    freebayes -f $REFERENCE $bamfile > $freebayesunfiltered

    freebayesvcf=$FREEBAYESDIR/$prefix.vcf
    echo 'Filtering freebayes variants: '$freebayesvcf
    vcftools --vcf $freebayesunfiltered --minQ 10 --min-meanDP 20 --recode --recode-INFO-all --out $freebayesvcf
    mv $freebayesvcf.recode.vcf $freebayesvcf
  fi

  # Run samtools mpileup andvariant calling
  mpileupfile=$SAMTOOLSDIR/$prefix.mpileup

  if [ ! -r $mpileupfile ]
  then
    echo 'Running mpileup: ' $mpileupfile  
    samtools mpileup -A -Q 0 --reference $REFERENCE $bamfile -o $mpileupfile
  fi
 
  if [ ! -r "$SAMTOOLSDIR/$prefix.samtools.vcf" ]; then
    samtoolsvcf=$SAMTOOLSDIR/$prefix.samtools.vcf
    java -cp $BINDIR/VariantValidator/src CallVariants flag_prefix=ILLUMINA_ pileup_file=$mpileupfile out_file=$samtoolsvcf
  fi

  # Create list of VCFs for merging
  filelist=$MERGINGDIR/$prefix.filelist.txt
  if [ -r $filelist ]
  then
    rm $filelist
  fi

  echo $ivarvcf > $filelist
  echo $freebayesvcf >> $filelist
  echo $samtoolsvcf >> $filelist
  
  echo 'Filelist: ' $filelist
  cat $filelist

  # Run merging and add allele frequencies
  mergedvcf=$MERGINGDIR/$prefix.allcallers.vcf
  echo 'Merging VCFs: '$mergedvcf
  java -cp $BINDIR/VariantValidator/src MergeVariants file_list=$filelist out_file=$mergedvcf illumina_bam=$bamfile
  
  combinedvcf=$MERGINGDIR/$prefix.allcallers_combined.vcf
  echo 'Merging VCFs: '$mergedvcf
  java -cp $BINDIR/VariantValidator/src CombineVariants vcf_file=$mergedvcf out_file=$combinedvcf genome_file=$REFERENCE gene_file=$GENES

  allelefreqvcf=$MERGINGDIR/$prefix.all_caller_freqs.vcf
  echo 'Adding allele frequencies: '$allelefreqvcf
  java -cp $BINDIR/VariantValidator/src AddAlleleFrequencies vcf_file=$mergedvcf illumina_mpileup=$mpileupfile out_file=$allelefreqvcf

done
