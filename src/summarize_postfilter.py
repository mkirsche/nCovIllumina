#!/usr/bin/env python

import os
import argparse
import pandas as pd
import numpy as np
pd.options.mode.chained_assignment = None

def generate_postfilter_summary(rundir):
    """
    Generate a summary table of postfilter results
    """
    
    alldata = pd.DataFrame()
    
    # loop through the variant data files in the postfilter run directory
    for entry in os.scandir(rundir):
        if entry.path.endswith('variant_data.txt'):
            vardata = entry.path
            var = pd.read_csv(vardata,sep='\t')
            
            # join this dataframe to all the others
            alldata = pd.concat([alldata,var],ignore_index=True)
    
    # output the concatenated table
    # get a list of columns
    cols = list(alldata)
    cols.insert(0, cols.pop(cols.index('sample')))
    alldata = alldata.reindex(columns=cols)
    alldata.to_csv(os.path.join(rundir,'postfilt_all.txt'),sep='\t',index=False)
    return(alldata)

def merge_snpeff_annotations(alldata,snpeff_report):
    """
    Merge annotations for each variant in table
    """

    annot = pd.read_csv(snpeff_report,sep='\t')
    annot.columns = ['chrom','pos','ref','alt','gene','ann','aa_mut']

    genes=[]
    anns=[]
    aa_muts=[]

    # loop through variants in concatenated postfilt table
    # add annotations if they are available
    for pos in alldata.pos:
        tmp = alldata[alldata.pos==pos]
        ref = tmp.ref.values[0]
        alt = tmp.alt.values[0]

        # find matching pos, ref, alt in annotations dataframe
        ann = annot[(annot.pos==pos) & (annot.ref==ref) & (annot.alt==alt)]
        if ann.empty:
            genes.append('.')
            anns.append('.')
            aa_muts.append('.')
        else:
            assert ann.shape[0]==1
            genes.append(ann.gene.values[0])
            anns.append(ann.ann.values[0])
            aa_muts.append(ann.aa_mut.values[0])

    alldata['gene']=genes
    alldata['ann']=anns
    alldata['aa_mut']=aa_muts

    return(alldata)
    
def parse_arguments():
   parser = argparse.ArgumentParser()
   parser.add_argument('--rundir', type=str, help='path to postfilter results for a particular run')
   parser.add_argument('--annot', type=str, help='path to snpeff results for a particular run')
   args = parser.parse_args()
   return(args)


if __name__ == "__main__":
    
    args = parse_arguments()
    alldata = generate_postfilter_summary(args.rundir)
    annot_data = merge_snpeff_annotations(alldata,args.annot)

    # reorder columns for ease of use
    annot_data = annot_data[['sample', 'chrom', 'pos', 'ref', 'alt', 'consensus_base', 'gene', 'ann', 'aa_mut',
    'in_consensus', 'unambig','status','case','description','homopolymer', 
    'read_depth', 'depth_thresh', 'allele_freq', 'alleles', 'strand_counts',
    'depth_flag', 'ntc_flag', 'indel_flag', 'vc_flag', 'mixed_flag',
    'maf_flag', 'sb_flag', 'key_flag', 'new_flag']]

    annot_data.to_csv(os.path.join(args.rundir,'postfilt_all_annot.txt'),sep='\t',index=False)

    # save another file with just variants in consensus genomes
    filtered_data = annot_data[(annot_data['in_consensus']!=False) & (annot_data['in_consensus']!='False')]
    filtered_data = filtered_data[(filtered_data['unambig']!=False) & (filtered_data['unambig']!='False')]
    filtered_data.to_csv(os.path.join(args.rundir,'postfilt_all_annot_consensus.txt'),sep='\t',index=False)