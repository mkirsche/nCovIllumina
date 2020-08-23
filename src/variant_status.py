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
    
    ## CASE 1
    if not pd.isna(data['depth_flag']):
        return(1)
    
    ## CASE 2
    if not pd.isna(data['ntc_flag']):
        return(2)
    
    ## CASE 3
    if not pd.isna(data['vc_flag']):
        return(3)
        
    ## CASE 4
    if data['allele_freq']<maf_flag and data['in_consensus']:
        return(4)
    
    ## CASE 5
    if data['allele_freq']>(1-maf_flag) and data['in_consensus']==False:
        return (5)
    
    
    # situtions with mixed frequency variants
    
    if not pd.isna(data['mixed_flag']):
        
        ## CASE 6
        if data['in_consensus']==False and (not pd.isna(data['sb_flag'])):
            return(6)
        
        ## CASE 7
        else:
            other_allele_freq = float(int(data['alleles'].split(':')[11])/data['depth'])
            if (other_allele_freq-0.02 <= (1-data['allele_freq']) <= other_allele_freq+0.02) and data['homopolymer'] and data['in_consensus']:
                return(7)
        
            ## CASE 8
            else:
                return(8)
    
    # at this point we know the frequency is either <maf_flag or >(1-maf_flag)
    # and that the in consensus status matches the high/low status
    
    # specific situations for variants not seen before
    if not pd.isna(data['new_flag']):
        
        ## CASE 9
        if data['allele_freq']>0.9 and data['in_consensus']:
            return(9)
        
        ## CASE 10
        elif data['in_consensus']:
            return(10)
    
    # if there are no other worrisome flags
    # ignore low frequency variants and accept high frequency variants
    # remember we already know the consensus status matches the high/low status
    # we also know that illumina is not mixed or maybe, and that if there is illumina data, illumina status matches high/low status
    
    ## CASE 11
    if data['allele_freq']<maf_flag and data['unambig']:
        return(11)
    
    ## CASE 12
    if data['allele_freq']>(1-maf_flag) and data['unambig']:
        return(12)
    
    # at the end, ensure we catch all remaining consensus N variants
    
    ## CASE 13
    if data['unambig']==False:
        return(13)
    
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