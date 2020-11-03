alias ls="ls --color=auto"
alias ll="ls -l --color=auto"

PS1='${debian_chroot:+($debian_chroot)}\[\033[01;33m\]\u@\h\[\033[00m\][\t]:\[\033[01;34m\]\W\[\033[00m\]\$ '

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!

__conda_setup="$('/opt/conda/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
	eval "$__conda_setup"
else
	if [ -f "/opt/conda/etc/profile.d/conda.sh" ]; then
		. "/opt/conda/etc/profile.d/conda.sh"
	else
		export PATH="/opt/conda/bin:$PATH"
	fi
fi
unset __conda_setup
source /opt/conda/etc/profile.d/conda.sh

conda activate artic-ncov2019-illumina

# compile java libraries
javac "/home/idies/workspace/covid19/code/nCovIllumina/VariantValidator/src"/*.java
javac "/home/idies/workspace/covid19/code/vcfigv/src"/*.java

# deal with primer scheme rename bugs
#primer_schemes=/home/idies/workspace/covid19/code/nCovIllumina/artic-ncov2019/primer_schemes

#samtools faidx "$primer_schemes/SARS-CoV-2/V3/nCoV-2019.reference.fasta"
#for f in "$primer_schemes/SARS-CoV-2/V3/"*; do ln -sf "$f" "${f/nCoV-2019/SARS-CoV-2}"; done
#ln -sf "$primer_schemes/SARS-CoV-2" "$primer_schemes/nCoV-2019"
#ln -sf "$primer_schemes" "/home/idies/workspace/covid19/code/nCovIllumina/artic-ncov2019/primer-schemes"
