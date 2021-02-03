FROM continuumio/miniconda3
# continuumio/miniconda3 is FROM debian:latest

# add conda to PATH
ENV PATH /opt/conda/bin:$PATH

# Make RUN commands use `bash --login` (always source ~/.bashrc on each RUN)
SHELL ["/bin/bash", "--login", "-c"]

# install apt depedencies
RUN apt-get update \
    && mkdir /usr/share/man/man1 \
    && apt-get install --no-install-recommends -y git texlive-xetex apt-transport-https ca-certificates wget unzip bzip2 openjdk-11-jdk-headless curl \
    && update-ca-certificates \
    && apt-get -qq -y autoremove \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/* /var/log/dpkg.log 

RUN useradd idies \
    && mkdir -p /home/idies/workspace \
    && chown -R idies:idies /home/idies \
    && mkdir -p /opt/nCovIllumina \
    && chown -R idies:idies /opt/nCovIllumina \
    && chown -R idies:idies /opt/conda

USER idies

# update conda
RUN conda install -y python=3 \
    && conda update -y conda \
    && conda clean --all --yes

WORKDIR /opt/nCovIllumina
# clone VCF IGV repo and install local IGV
RUN git clone https://github.com/mkirsche/vcfigv \
    && wget https://data.broadinstitute.org/igv/projects/downloads/2.8/IGV_2.8.10.zip -P vcfigv \
    && unzip -d vcfigv vcfigv/IGV_2.8.10.zip \
    && rm vcfigv/IGV_2.8.10.zip \
    && git clone --recurse-submodules https://github.com/connor-lab/ncov2019-artic-nf \
    && git clone https://github.com/mkirsche/VariantValidator.git \
    && git clone --recurse-submodules https://github.com/artic-network/artic-ncov2019 \
    && git clone https://github.com/artic-network/primer-schemes

RUN conda env create -f ncov2019-artic-nf/environments/illumina/environment.yml

# install nextstrain pipeline
RUN curl http://data.nextstrain.org/nextstrain.yml --compressed -o nextstrain.yml \
    && conda env create -f nextstrain.yml

# install pangolin pipeline
RUN git clone https://github.com/cov-lineages/pangolin.git \
    && conda env create -f pangolin/environment.yml \
    && conda activate pangolin \
    && cd pangolin && python setup.py install

COPY environment.yml .
RUN conda env create -f environment.yml

RUN conda install -c bioconda -y nextflow matplotlib

USER root
COPY --chown=idies:idies . .

USER idies
COPY bashrc /home/idies/.bashrc
WORKDIR /home/idies
