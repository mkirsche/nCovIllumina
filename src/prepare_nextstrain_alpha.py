#!/usr/bin/env python
"""
Script to prepare nextstrain alpha files
"""
## TODO: 
# Add extra metadata columns if provided in next_meta parameter 

import pandas as pd
import numpy as np 
import json , os ,sys
import argparse
import random , time
from datetime import datetime , date , timedelta
from pandas.io.json import json_normalize
import glob ,re , tempfile ,shutil
import random , time
from datetime import datetime , date , timedelta
from pyfaidx import Fasta
from datetime import date
import warnings
from pytz import timezone
from Bio import SeqIO
import yaml
from shutil import copyfile

warnings.simplefilter(action='ignore', category=FutureWarning)
pd.options.mode.chained_assignment = None  # default='warn'

#DATE_FMT ="%Y%m%d"
DATE_FMT ="%Y-%m-%d"
REF_LENGTH = 29903
count_Ns = 5000
N_DAYS=14

CUR_DATE = datetime.now(timezone('US/Eastern'))
#SUB_DATE = self.CUR_DATE.strftime(self.SUB_FMT)
#CUR_DATE = self.CUR_DATE.strftime(self.DATE_FMT)

def log(message):
    """ Log messages to standard output. """
    print(time.ctime() + ' --- ' + message, flush=True)

def generate_date(n_days,date_fmt):
    """ Generate random date with in the last n days """
    end = datetime.now(timezone('US/Eastern'))
    start = end - timedelta(days=n_days)
    random_date = start + (end - start) * random.random()
    return random_date.strftime(date_fmt)
    #return random_date.strptime(date_fmt)

def prepare_metadata(sname_list, meta_dict, len_dict, pangolin_dict, next_dict, n_days,date_fmt,out_file ):
    """ Prepare metadata dict as per the config fields """
    meta_df = pd.DataFrame(columns = meta_dict.keys())
    samples = {'strain': sname_list}
    meta_df = meta_df.append(pd.DataFrame(samples))
    cur_date = datetime.now(timezone('US/Eastern'))
    for col in meta_df.columns:
        #if col == "strain":
        #   meta_df[col] = sname_list
        if col not in ["strain" , "pangolin_lineage" , "Nextstrain_clade" , "length", "date" , "date_submitted"]:
           meta_df[col] = meta_dict[col]
        if col == "pangolin_lineage":
           meta_df['pangolin_lineage'] = meta_df['strain'].map(pangolin_dict)
        if col == "Nextstrain_clade":
           meta_df['Nextstrain_clade'] = meta_df['strain'].map(next_dict)
        if col == "length":
           meta_df['length'] = meta_df['strain'].map(len_dict)
        if col == "date":
           meta_df['date'] = [generate_date(n_days,date_fmt) for i in range(0,len(sname_list))]
        if col == "date_submitted":
           meta_df['date_submitted'] = cur_date.strftime(date_fmt)
    meta_df.to_csv(out_file, mode='w', sep="\t",header=True,index=False)
    return meta_df

def get_fasta_lengths(fasta):
    fa_lens = []
    N_counts = []
    for seq_record in SeqIO.parse(fasta, "fasta"):
        A_count = seq_record.seq.count('A')
        C_count = seq_record.seq.count('C')
        G_count = seq_record.seq.count('G')
        T_count = seq_record.seq.count('T')
        N_count = seq_record.seq.count('N')
        fa_lens.append(len(seq_record))
        N_counts.append(N_count)
    return fa_lens, N_counts

def getKeysByValues(dictOfElements, listOfValues):
    listOfKeys = list()
    listOfItems = dictOfElements.items()
    for item  in listOfItems:
        if item[1] in listOfValues:
           listOfKeys.append((item[1], item[0]))
    return  listOfKeys

def get_file_list(file_list,file_pattern):
    """
    get file list of consensus fasta from RUN_DIR and FASTA_PATH

    """
    c_list = []
    for i in file_list:
        cfile = glob.glob(i + file_pattern)[0]
        c_list.append(cfile)
    return c_list

def get_files_from_path(rundir,fasta_path,file_pattern):
    """
    get file list of consensus fasta from RUN_DIR and FASTA_PATH

    """
    c_list = []
    fullpath = os.path.join(rundir, fasta_path)
    file_list = glob.glob(fullpath + "/" + file_pattern )  # You may use iglob in Python3     
    assert file_list is not None, "Fasta Files with pattern {0} not present in {1}".format(file_pattern , fullpath)
    for i in file_list:
        cfile = glob.glob(i + file_pattern)[0]
        c_list.append(cfile)
    return c_list

def get_fasta_header(seq):
    """
    get header from fasta file
    """
    with open(seq,'r') as fd:
         header = []
         for line in fd:
             if line[0]=='>':
                header.append(line.strip().split(">")[1].split(" ")[0])
    return header

def parse_tsv(file,col=None):
    """ Parse tsv files into a pandas dataframe"""
    if col:
       df = pd.read_table(file,sep="\t",header=col,skip_blank_lines=True)
    else:
       df = pd.read_table(file,sep="\t",header=0,skip_blank_lines=True)
    log("INFO : Parsed number of rows :" +  str(df.shape[0]) + " , columns :" + str(df.shape[1]) )
    return df 

def parse_tsv_to_dict(file,col1,col2):
    """ Parse tsv files into a dict of 2 columns"""
    df = pd.read_table(file,sep="\t",header=0,skip_blank_lines=True) 
    vdict = dict(zip(df[col1], df[col2])) 
    return vdict

def parse_csv_to_dict(file,col1, col2):
    """ Parse tsv files into a dict of 2 columns"""
    df = pd.read_csv(file, sep=",",header=0,skip_blank_lines=True) 
    vdict = dict(zip(df[col1], df[col2])) 
    return vdict

def parse_yaml(file):
    """ Parse yaml file into a dict""" 
    try:
       with open(file) as f:
            return yaml.safe_load(f)  
    except:
       raise

def write_yaml(conf_dict,out_yaml):
    """ Write dict to a yaml"""
    try:
      with open(out_yaml, 'w') as out:
         yaml.dump(conf_dict, out, default_flow_style=False)
    except:
       raise
 
def concat_fasta_files(fa_list, out):
    """
    Function to concat fasta files from a list
    """
    filt_fnames = []
    with open(out, 'w') as outfile:
       for fname in fa_list:
           ffile = glob.glob(fname)[0]
           g_lengths, n_counts = get_fasta_lengths(ffile)
           #if g_lengths[0] < 25000 or n_counts[0] < 5000:
           filt_fnames.append(ffile)
           with open(ffile) as infile:
                for line in infile:
                    outfile.write(line)
           #else:
           #   log("INFO : Skipping {0} from alpha Genome Length :  {1} , N_counts : {2}".format(fname,g_lengths[0],n_counts[0]))
    return filt_fnames

def get_latest_file(path, *paths):
    """Returns the name of the latest (most recent) file 
    of the joined path(s)"""
    fullpath = os.path.join(path, *paths)
    list_of_files = glob.glob(fullpath)  # You may use iglob in Python3
    if not list_of_files:                # I prefer using the negation
        return None                      # because it behaves like a shortcut
    latest_file = max(list_of_files, key=os.path.getctime)
    _, filename = os.path.split(latest_file)
    return filename

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Script to Parse new sequencing runs from alpha nextstrain")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("-g",dest="FA_FILE",type=str, help="Path to the multifasta file")
    group.add_argument("--rundir",dest="RUN_DIR",type=str, help="Path to the sequencing runs folder")
    parser.add_argument("--fasta-path",dest="FASTA_PATH",type=str,help="Path to the draft consensus fasta folder")
    parser.add_argument("--file-pattern",dest="FASTA_PAT",type=str, default="complete.fasta", help="File pattern of fasta files")
    parser.add_argument("--metadata-config",dest="CONFIG_META",type=str, required=True, help="Path to a yaml file with standard metadata file")
    parser.add_argument("--next_meta",dest="NEXT_META",type=str, required=False, help="Path to a tsv file real metadata file for samples run")
    parser.add_argument("--pangolin_clade",dest="P_CLADE",type=str, required=False, help="Path to a csv file with pangolin clades")
    parser.add_argument("--nextstrain_clade",dest="NEXT_CLADE",type=str, required=False, help="Path to a tsv file nextstrain clades")
    parser.add_argument("--global-seq",dest="GLOBAL_SEQ",type=str, required=False, help="Path to a subsampled fasta file")
    parser.add_argument("--global-meta",dest="GLOBAL_META",type=str, required=False, help="Nextstrain metadata file for the subsampled fasta")
    parser.add_argument("--run_name",dest="RUN_NAME",type=str, required=True, help="Run name for the nextstrain run")
    parser.add_argument("-out",dest="OUTPUT_DIR",type=str, required=True, help="Path to output directory for alpha nextstrain")
    
    args = parser.parse_args()
    
    if bool(args.RUN_DIR) ^ bool(args.FASTA_PATH):
       parser.error('--rundir, --fasta-path must be given together')
    if bool(args.GLOBAL_SEQ) ^ bool(args.GLOBAL_META):
       parser.error('--global-seq , --global-meta must be given together') 
    outdir = args.OUTPUT_DIR
     
    if not os.path.exists(outdir):
       os.makedirs(outdir)

    if args.FA_FILE:
       fasta = args.FA_FILE
       ## TODO : Check if any fasta file has n_counts > 5000  and length < REF_LEN if FA_FILE is provided
    else:
       # Make multifasta file
       fasta = os.path.join(outdir,"run_sequences.fasta")
       fa_file_list = get_files_from_path(rundir,fasta_path,file_pattern)
       concat_fasta_files(fa_file_list,fasta)
    
    sample_names = get_fasta_header(fasta) 
    glens , n_counts = get_fasta_lengths(fasta)
    glens_dict = dict ( zip ( sample_names, glens ))

    if args.CONFIG_META:
       meta_fields = parse_yaml(args.CONFIG_META)
       config_dir = os.path.dirname(args.CONFIG_META)
       conf_yaml = os.path.join(config_dir , "config.yaml")
       build_yaml = os.path.join(config_dir , "builds.yaml")
       if not os.path.exists(conf_yaml) or not os.path.exists(build_yaml):
          log("Error : Nextstrain build files 1) config.yaml 2) builds.yaml missing in " +  config_dir)
          sys.exit(1)

    if args.NEXT_META:
       next_metadata = args.NEXT_META
       local_meta = parse_tsv(args.NEXT_META,col=0)
       mandatory_cols = [ 'strain' , 'date' , 'date_submitted']
       check_cols = local_meta.columns
       missed_man_cols = [ k for k in mandatory_cols if k not in check_cols ]
       if len(missed_man_cols) > 0:
          log("Error : Metadata file provided is missing one of the columns\n-" + "\n-".join(missed_man_cols))
          log("INFO : Please provide correct metadata file or run excluding --next_meta parameter to auto generate metadata")
          sys.exit(1)
       missed_cols = [ k for k in meta_fields if k not in check_cols ]
       extra_cols = [ k for k in check_cols if k not in meta_fields ]
       ### TODO : Add extra columns to global meta using pandas merge ; getting that to work
       ### For now just dropping extra columns
       local_meta.drop(extra_cols, inplace=True, axis=1)
       for i in missed_cols:
           if i not in mandatory_cols:
              local_meta[i] = meta_fields[i]
       # Check if metadata field "strain" is unique
       uniqueSamples = local_meta['strain'].unique()
       if len(uniqueSamples) != local_meta.shape[0]:
          log("Error : Metadata file has non unique values for strain column ")
          sys.exit(1)

       if local_meta['strain'].isnull().values.any() or (local_meta['strain'] == '').sum() > 0 :
          log("Error : Metadata file should contain a non empty string ")
          sys.exit(1)
       
       try:
          log("INFO: Checking date column for metadata")
          pd.to_datetime(local_meta['date'], format="%Y-%m-%d", errors='raise')
          # do something
       except ValueError:
          log("Error : Invalid date specified for date column ; should be in the format YYYY-MM-DD ")    
          sys.exit(1) 
       try:
          log("INFO: Checking date_submitted for metadata")
          pd.to_datetime(local_meta['date_submitted'], format="%Y-%m-%d", errors='raise')
          # do something
       except ValueError:
          log("Error : Invalid date specified for date_submitted column ; should be in the format YYYY-MM-DD ")       
          sys.exit(1)
       # parse pangolin
       if args.P_CLADE:
          pangolin_dict = parse_csv_to_dict(args.P_CLADE,"taxon" , "lineage")
       else:
          log("WARNING : Pangolin  clade output file not provided; Set to ? for all samples " )
          pangolin_dict = dict(zip(sample_names,["?" for i in sample_names ])) 
       # parse nextstrain
       if args.NEXT_CLADE:
          next_dict = parse_tsv_to_dict(args.NEXT_CLADE,"name","clade") 
       else:
          log("WARNING : Nextstrain clade output file not provided; Set to ? for all samples " )
          next_dict = dict(zip(sample_names,["?" for i in sample_names ])) 

       local_meta['pangolin_lineage'] = local_meta['strain'].map(pangolin_dict)
       local_meta['Nextstrain_clade'] = local_meta['strain'].map(next_dict)
    else:
       ### Create fake metadata
       next_metadata = os.path.join(outdir,"run_sequences_metadata.tsv")
       # parse pangolin
       if args.P_CLADE:
          pangolin_dict = parse_csv_to_dict(args.P_CLADE,"taxon" , "lineage")
       else:
          log("WARNING : Pangolin  clade output file not provided; Set to ? for all samples " )
          ## TODO: Run pangolin script
          pangolin_dict = dict(zip(sample_names,["?" for i in sample_names ])) 
       # parse nextstrain
       if args.NEXT_CLADE:
          ## TODO: Run nextstrain clade script
          next_dict = parse_tsv_to_dict(args.NEXT_CLADE,"name","clade") 
       else:
          log("WARNING : Nextstrain clade output file not provided; Set to ? for all samples " )
          next_dict = dict(zip(sample_names,["?" for i in sample_names ])) 
       log("INFO : Generating metadata for the samples " )
       local_meta = prepare_metadata(sample_names, meta_fields, glens_dict, pangolin_dict, next_dict, N_DAYS,DATE_FMT, next_metadata)
       log("INFO : Output local metadata : " + next_metadata )
    
    if args.GLOBAL_META:
       g_df = parse_tsv(args.GLOBAL_META,col=0)
       g_df['strain'] = g_df['strain'].astype(str)
       #all_seq_meta_df = pd.concat([local_meta,g_df],axis=1)
       local_meta['strain'] = local_meta['strain'].astype(str)
       all_seq_meta_df = pd.concat([local_meta,g_df,], ignore_index=True)
       #all_seq_meta_df = pd.merge(local_meta, g_df, how='outer',on='strain',left_index=True, right_index=True,suffixes=('', '_DROP')).filter(regex='^(?!.*_DROP)')
       all_seq_meta_df.replace(np.nan, "Unknown", inplace=True)
       log("INFO:  Combining local and global metadata for nextstrain" )     
       all_seq_meta = os.path.join(outdir,"all_sequences_metadata.tsv")
       all_seq_meta_df.to_csv(all_seq_meta, mode='w', sep="\t",header=True,index = False)
       log("INFO : Output final metadata : " + all_seq_meta )
    
    if args.GLOBAL_SEQ:
       all_seq_fasta = os.path.join(outdir,"all_sequences.fasta")
       concat_fasta_files([ fasta , args.GLOBAL_SEQ ],all_seq_fasta)
       log("INFO : Output final sequences : " + all_seq_fasta )
       
       log("INFO : Writing nextstrain config files")
       profile_dir = os.path.join(outdir , "custom_profile")
       if not os.path.exists(profile_dir):
          os.makedirs(profile_dir)
       copyfile( build_yaml , os.path.join(profile_dir, "builds.yaml"))

    if args.RUN_NAME:
       run_name = args.RUN_NAME
         
    if conf_yaml:
       conf_dict = parse_yaml(conf_yaml)
       for key in conf_dict:
           if key == "configfile":
              conf_dict[key][1] = os.path.join(profile_dir, "builds.yaml")
           if key == "config":
              for i in range(len(conf_dict[key])):
                     k,v = conf_dict[key][i].split("=")
                     if k == "sequences":
                        v = all_seq_fasta
                     if k == "metadata":
                        v = all_seq_meta
                     if k == "outdir":
                        v = outdir + "/alpha"
                     if k == "run_name":
                        v = run_name
                     conf_dict[key][i] = k + "=" + v
    write_yaml(conf_dict, os.path.join(profile_dir, "config.yaml"))      
    log("INFO : Done !!!")
