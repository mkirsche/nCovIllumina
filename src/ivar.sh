WORKINGDIR=`pwd`
DATADIR=$1
# Install Nextflow
#echo 'Installing nextflow'
#if [ ! -r $WORKINGDIR/nextflow ]
#then
#    curl -s https://get.nextflow.io | bash
#fi
EXTRAARGS=`echo "${@:2}"`
echo 'Extra args: ' $EXTRAARGS
nextflow run connor-lab/ncov2019-artic-nf --illumina --prefix test --directory $DATADIR $EXTRAARGS -profile conda
