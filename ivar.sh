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
source /home/idies/workspace/covid19/code/nCovIllumina/bashrc
conda activate artic-ncov2019-illumina
nextflow run connor-lab/ncov2019-artic-nf --with-docker ncovillumina --illumina --prefix test --directory $DATADIR $EXTRAARGS
