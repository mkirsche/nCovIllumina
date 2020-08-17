WORKINGDIR=`pwd`
DATADIR=$1
# Install Nextflow
echo 'Installing nextflow'
if [ ! -r $WORKINGDIR/nextflow ]
then
    curl -s https://get.nextflow.io | bash    
fi


$WORKINGDIR/nextflow run connor-lab/ncov2019-artic-nf -profile conda --illumina --prefix test --directory $DATADIR
