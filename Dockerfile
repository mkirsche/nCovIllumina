FROM continuumio/miniconda3
# continuumio/miniconda3 is FROM debian:latest

# add conda to PATH
ENV PATH /opt/conda/bin:$PATH

# Make RUN commands use `bash --login` (always source ~/.bashrc on each RUN)
SHELL ["/bin/bash", "--login", "-c"]

# configure user/group permissions
# ARG USER_ID
# ARG GROUP_ID
# ARG ENVIRONMENT

# RUN if [[ $ENVIRONMENT != "WIN" ]]; then addgroup --gid $GROUP_ID user; else addgroup --gid 1000 user; fi 
# RUN if [[ $ENVIRONMENT != "WIN" ]]; then adduser --disabled-password --gecos '' --uid $USER_ID --gid $GROUP_ID user; else adduser --disabled-password --gecos '' --uid 1000 --gid 1000 user; fi 

# install apt depedencies
RUN apt-get update \
    && apt-get install -y git texlive-xetex curl apt-transport-https ca-certificates wget unzip bzip2 \
    && update-ca-certificates

# install docker for sibling container usage: https://medium.com/@andreacolangelo/sibling-docker-container-2e664858f87a
RUN curl -sSL https://get.docker.com/ | sh \
    && usermod -aG docker root
#    && usermod -aG docker user

# free up space in image
RUN apt-get -qq -y remove curl \
    && apt-get -qq -y autoremove \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/* /var/log/dpkg.log 

# update conda
RUN conda install -y python=3 \
    && conda update -y conda \
    && conda clean --all --yes

# configure directory structure exactly as it is on SciServer for ease of transition
WORKDIR /home/idies/workspace/covid19/code

# link global conda to expected sciserver location
RUN ln -s /opt/conda/ /home/idies/workspace/covid19/miniconda3

# clone VCF IGV repo and install local IGV
RUN git clone https://github.com/mkirsche/vcfigv \
    && wget https://data.broadinstitute.org/igv/projects/downloads/2.8/IGV_2.8.10.zip -P vcfigv \
    && unzip -d vcfigv vcfigv/IGV_2.8.10.zip \
    && rm vcfigv/IGV_2.8.10.zip

# install nextflow pipeline
WORKDIR /home/idies/workspace/covid19/code/
RUN git clone --recurse-submodules https://github.com/connor-lab/ncov2019-artic-nf \
    && conda env create -f ncov2019-artic-nf/environments/illumina/environment.yml

# install nextstrain pipeline
WORKDIR /home/idies/workspace/covid19/code/
RUN curl http://data.nextstrain.org/nextstrain.yml --compressed -o nextstrain.yml \
    && conda env create -f nextstrain.yml

# install pangolin pipeline
WORKDIR /home/idies/workspace/covid19/code/
RUN git clone https://github.com/cov-lineages/pangolin.git \
    && conda env create -f pangolin/environment.yml \
    && cd pangolin && python setup.py install

# install pipeline code
# WORKDIR /home/idies/workspace/covid19/code
# RUN git clone --recurse-submodules https://github.com/mkirsche/nCovIllumina
WORKDIR /home/idies/workspace/covid19/code/nCovIllumina
RUN conda install -c bioconda -y nextflow
COPY . .
RUN conda env create -f environment.yml
RUN git clone https://github.com/mkirsche/VariantValidator.git \
    && git clone --recurse-submodules https://github.com/artic-network/artic-ncov2019 \
    && git clone https://github.com/artic-network/primer-schemes

# configure bash environment
ENV PATH="/home/idies/workspace/covid19/code/jdk-14/bin:${PATH}"
RUN cat /home/idies/workspace/covid19/code/nCovIllumina/bashrc >> ~/.bashrc

# install missing dependencies
RUN source ~/.bashrc \
    && conda activate artic-ncov2019-illumina \
    && conda install -y -c bioconda matplotlib

# set default working directory
WORKDIR /home/idies/workspace/covid19/code/nCovIllumina
#USER user
