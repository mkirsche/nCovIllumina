# Pipeline for processing Illumina reads
WORKINGDIR=`pwd`
if [ "$(uname -s)" = 'Linux' ]; then
    BINDIR=$(dirname "$(readlink -f "$0" || echo "$(echo "$0" | sed -e 's,\\,/,g')")")
else
    BINDIR=$(dirname "$(readlink "$0" || echo "$(echo "$0" | sed -e 's,\\,/,g')")")
fi

REFERENCE=$BINDIR/reference/nCoV-2019.reference.fasta

if [ ! -r $REFERENCE ]
then
  echo 'Downloading VariantValidator submodule'
  cd $BINDIR
  git submodule update --init --recursive
  cd $WORKINGDIR
fi

javac $BINDIR/VariantValidator/src/*.java

if [ ! -d $WORKINGDIR/results ]
then
  echo 'Running ivar'
  DATADIR=$1
  $BINDIR/ivar.sh $DATADIR
fi


# Set up output directories for freebayes, samtools, and merging

FREEBAYESDIR=$WORKINGDIR/results/freebayes
if [ ! -d $FREEBAYESDIR ]
then
  mkdir $FREEBAYESDIR
fi

SAMTOOLSDIR=$WORKINGDIR/results/samtools
if [ ! -d $SAMTOOLSDIR ]
then
  mkdir $SAMTOOLSDIR
fi

MERGINGDIR=$WORKINGDIR/results/merging
if [ ! -d $MERGINGDIR ]
then
  mkdir $MERGINGDIR
fi

# Iterate over BAM files and run variant calling pipeline for each
for bamfile in `ls $WORKINGDIR/results/ncovIllumina_sequenceAnalysis_trimPrimerSequences/*.primertrimmed.sorted.bam`
do
  basename=`basename $bamfile`
  prefix=${basename%%.*}
  echo 'Processing '$prefix

  # Convert iVar TSV to VCF
  ivartsv=$WORKINGDIR/results/ncovIllumina_sequenceAnalysis_callVariants/$prefix.variants.tsv
  ivarvcf=${ivartsv%.*}.vcf

  echo 'Coverting iVar to VCF: '$ivarvcf
  java -cp $BINDIR/VariantValidator/src IvarToVcf table_file=$ivartsv out_file=$ivarvcf
  
  # Index BAM filefor freebayes
  if [ ! -r $bamfile.bai ]
  then
    samtools index $bamfile
  fi

  # Call and filter freebayes variants
  freebayesunfiltered=$FREEBAYESDIR/$prefix.unfiltered.vcf
  echo 'Calling freebayes variants: ' $freebayesunfiltered
  freebayes -f $REFERENCE $bamfile > $freebayesunfiltered

  freebayesvcf=$FREEBAYESDIR/$prefix.vcf
  echo 'Filtering freebayes variants: '$freebayesvcf
  vcftools --vcf $freebayesunfiltered --minQ 10 --min-meanDP 20 --recode --recode-INFO-all --out $freebayesvcf
  mv $freebayesvcf.recode.vcf $freebayesvcf

  # Run samtools mpileup andvariant calling
  mpileupfile=$SAMTOOLSDIR/$prefix.mpileup

  if [ ! -r $mpileupfile ]
  then
    echo 'Running mpileup: ' $mpileupfile  
    samtools mpileup --reference $REFERENCE $bamfile -o $mpileupfile
  fi
 
  samtoolsvcf=$SAMTOOLSDIR/$prefix.samtools.vcf
  java -cp $BINDIR/VariantValidator/src CallVariants flag_prefix=ILLUMINA_ pileup_file=$mpileupfile out_file=$samtoolsvcf

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

  allelefreqvcf=$MERGINGDIR/$prefix.all_caller_freqs.vcf
  echo 'Adding allele frequencies: '$allelefreqvcf
  java -cp $BINDIR/VariantValidator/src AddAlleleFrequencies vcf_file=$mergedvcf illumina_mpileup=$mpileupfile out_file=$allelefreqvcf

done

