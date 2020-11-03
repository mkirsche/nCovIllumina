# nCovIllumina

This repository contains a pipeline for processing Illumina nCov data, using [an existing ArticNextflow pipeline](https://github.com/connor-lab/ncov2019-artic-nf), and performing validation against variant calls from FreeBayes and against allele frequency thresholds.

## Dependencies

This pipeline requires the following:
* Conda, for both running the Nextflow pipeline and installing other software for validation
* The artic Nextflow pipeline linked above installed in the working directory, or root access so that it can be installed as the first step of the pipeline
* Java or openjdk
* freebayes
* samtools

The included environment.yml file contains a conda environment which includes openjdk, freebayes, samtools, and all of these tools' dependencies

## Usage

To run the entire pipeline:
```
./pipeline.sh <datadir>
  Here <datadir> is a directory containing the sequencing reads as zipped FASTQ files.
```

To run only the iVar Nextflow pipeline (this is a subroutine of the overall pipeline)
```
./ivar.sh <datadir>
```

## Outputs

The iVar Nextflow pipeline produces a directory named "results" within the working directory.  This contains the following outputs (as well as other subfolders with intermediate files):

* ncovIllumina_sequenceAnalysis_makeConsensus contains a FASTA file giving the iVar consensus genome sequences for all individuals (prefix.primertrimmed.consensus.fa)
* ncovIllumina_sequenceAnalysis_callVariants contains the iVar variant calls in TSV format (prefix.variants.tsv)
* ncovIllumina_sequenceAnalysis_trimPrimerSequences contains the read alignments to the reference after primer trimming is performed (prefix.mapped.primertrimmed.sorted.bam)

In addition, the next steps of the pipeline augment this results folder with the following subfolders:

* freebayes contains the variant calls from freebayes (prefix.freebayes.vcf)
* samtools contains the mpileup file (prefix.mpileup) as well as the variant calls based on an mpileup allele frequency cutoff of 0.15 (prefix.samtools.vcf)
* merging contains a merged VCF containing VCFs from all three callers which has allele frequencies annotated (prefix.all_caller_freqs.vcf)

This enable the flagging of iVar variants which have lower than expected allele frequencies or which don't have support from other variant callers.

## Docker container

A Dockerized version of this pipeline can be run using the following commands.

First build the Docker image with:
```
docker image build . -t ncovillumina
```

Because nextflow requires connection to Docker, we enable sibling containers by binding the docker socket to our container.

This container also attached an Illumina run folder to the `/data` folder within the container:
```
docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock --mount type=bind,source=/home/idies/workspace/covid19/illumina/200421_run1,target=/data ncovillumina bash
```

Once in the container, run the pipeline on the mounted folder with:
```
/home/idies/workspace/covid19/code/nCovIllumina/pipeline.sh /data
```

This will output a `results` folder in the active directory, which can be inspected in the container.

Once it is confirmed good to go, it can be copied over to the mounted data partition and accessed outside of the container:
```
mv results /data
```
