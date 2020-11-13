INPUTDIR=$1
FILTEREDINPUTDIR=$2
BINDIR=$3
MIN_READ_LENGTH=$4
MAX_READ_LENGTH=$5

if [ ! -r $FILTEREDINPUTDIR ]
then
    mkdir $FILTEREDINPUTDIR
    for i in `ls $INPUTDIR/*.fastq.gz`
    do
        echo 'Copying and unzipping ' $i
        filename=`basename $i`
        cp $i $FILTEREDINPUTDIR
        gunzip $FILTEREDINPUTDIR/$filename
    done
    javac $BINDIR/FilterReads.java
    allfiles=`ls $FILTEREDINPUTDIR/*.fastq`
    echo 'Filtering reads by length'
    java -cp $BINDIR FilterReads $MIN_READ_LENGTH $MAX_READ_LENGTH $allfiles
    for i in $allfiles
    do
      echo 'Zipping filtered reads: '$i
      gzip $i
    done
fi
