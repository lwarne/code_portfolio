'''
Class for performing a difference in means t-test
'''

#typeing
from typing import Mapping, Set, Sequence, Tuple, TypeVar, List, Generic, Dict, Any

#data types
import pandas as pd
import numpy as np
import datetime as dt

#stats
from statsmodels.stats.weightstats import ttest_ind

D = TypeVar(dt.datetime)
DF = TypeVar(pd.Series)

class TS_ttester():
    ''' 
        Only does days right now
        treatment date day will be considered in the second group 
    '''
    
    #member variables
    look_back : int
    look_forward : int
    treatment_date : D
    left_date : D
    right_date : D
        
    def __init__(
        self,
        treatment_date : D,
        look_back : int, 
        look_forward : int
    ) -> None :
        
        # set up member variables
        self.treatment_date = treatment_date
        self.look_back = look_back
        self.look_forward = look_forward
        self.left_date = treatment_date - dt.timedelta( days= self.look_back )
        self.right_date = treatment_date + dt.timedelta( days= self.look_forward )
        
    def t_test(
        self, 
        series: DF
    ) -> Dict[str, Any]:
        
        #subset the data into appropriate buckets for comparison
        left_data = series.loc[ self.left_date:self.treatment_date]
        
        #use the right date that min(end of series, lookforward date)
        useable_right_date = min(max(series.index), self.right_date)
        right_data = series.loc[ self.treatment_date:useable_right_date]
        
        #perform the t-test
            # returns tuple of tstat, pvalue, df (degrees of freedom)
        tester = ttest_ind(x1 = left_data, x2 = right_data)
        
        #calcualte my own info 
        change_in_mean = right_data.mean() - left_data.mean()
        pooled_std = np.sqrt( ( (left_data.shape[0]-1) * left_data.var() + (right_data.shape[0]-1)  * right_data.var())
                    / (left_data.shape[0] + right_data.shape[0] - 2)
                    )
        scaled_change_in_mean = change_in_mean / pooled_std
        
        #construct dictionary 
        results = {
            'tstat' : tester[0],
            'pval' : tester[1],
            'df' : tester[2],
            'mean_diff' : change_in_mean,
            'pooled_std' : pooled_std,
            'scaled_mean_diff' : scaled_change_in_mean,
            'left_mean' : left_data.mean(), 
            'right_mean': right_data.mean()
        }
        
        return results, left_data, right_data

