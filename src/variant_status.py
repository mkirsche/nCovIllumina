#!/usr/bin/env python

import numpy as np
import pandas as pd
import sys
    
def case_by_flags(data,maf_flag):
    """
    Assign case numbers to specific variant situations
    """
    
    # convert the maf_flag into a fraction
    maf_flag = maf_flag/100.0
    
    # convert no NTC warning into NaN
    if data['ntc_flag']=='NTC=None':
        data['ntc_flag']=np.nan
    
    # situations that automatically lead to an alarm
    
    ## near depth threshold
    if not pd.isna(data['depth_flag']):
        return('COV')
    
    ## allele in negative control
    if not pd.isna(data['ntc_flag']):
        return('NTC')
    
    ## variant callers disagree
    if not pd.isna(data['vc_flag']):
        if data['allele_freq']>maf_flag: # worrisome disgreement for high freq variant
            return('DIS-HF')
        else: # less worrisome disagreement for low freq variant
            if data['in_consensus']==True:
                return('DIS-CV')
            else:
                return('DIS-LF')
        
    ## low frequency variant in consensus
    if data['allele_freq']<maf_flag and data['in_consensus']==True:
        return('LFC')
    
    ## high frequency variant not in consensus
    if data['allele_freq']>(1-maf_flag) and data['in_consensus']==False:
        return ('HFC')
    
    
    # situtions with mixed frequency variants
    other_allele_freq = float(int(data['alleles'].split(':')[11])/data['read_depth'])
    if not pd.isna(data['mixed_flag']):
        
        ## ignore variant due to strand bias
        if data['in_consensus']==False and (not pd.isna(data['sb_flag'])):
            return('SB')
        
        ## ignore mixture due to homopolymer
        elif (other_allele_freq-0.02 <= (1-data['allele_freq']) <= other_allele_freq+0.02) and data['homopolymer'] and data['in_consensus']:
            return('HP')
        
        ## consensus contains ambiguity codes
        elif data['in_consensus']=='IUPAC':
            return('MIX-A')
        
        ## all other mixed variants
        else:
            return('MIX-M')
    
    # at this point we know the frequency is either <maf_flag or >(1-maf_flag)
    # and that the in consensus status matches the high/low status
    
    # specific situations for variants not seen before
    if not pd.isna(data['new_flag']):
        
        ## new position at high frequency
        if data['allele_freq']>0.9 and data['in_consensus']==True:
            return('NEW-HF')
        
        ## new position at intermediate frequency
        elif data['in_consensus']==True:
            return('NEW-MF')
    
    # special designation for variants with ambiguity codes
    if data['in_consensus']=='IUPAC':
        return('MIX-A')
    
    # if there are no other worrisome flags
    # ignore low frequency variants and accept high frequency variants
    # remember we already know the consensus status matches the high/low status
    
    ## safely ignore low frequency variant
    if data['allele_freq']<maf_flag and data['unambig']:
        return('LFV')
    
    ## safely accept high frequency variant
    if data['allele_freq']>(1-maf_flag) and data['unambig']:
        return('HFV')
    
    # at the end, ensure we catch all remaining consensus N variants
    if data['unambig']==False:
        return('UNK-C')
    
    # all cases should be covered by this point
    # we should never get here
    sys.exit('you found a scenario not covered; please modify case_by_flags')


def status_by_case(variant_data,case_definitions,maf_flag):
    
    # load a text file with case definitions
    defs = pd.read_csv(case_definitions)
    
    # determine the case for this particular variant
    case = case_by_flags(variant_data,maf_flag)
    
    # get description and status for this case from definitions table
    current_case = defs[defs.case==case]
    description = current_case.description.values[0]
    status = current_case.status.values[0]
    
    return(case,description,status)