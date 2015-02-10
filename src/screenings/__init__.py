#!/usr/bin/env python

# Copyright (C) <2015> EMBL-European Bioinformatics Institute

# This program is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of
# the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.

# Neither the institution name nor the name screenings can
# be used to endorse or promote products derived from this
# software without prior written permission. For written
# permission, please contact <marco@ebi.ac.uk>.

# Products derived from this software may not be called
# screenings nor may screenings appear in their names
# without prior written permission of the developers.
# You should have received a copy of the GNU General Public
# License along with this program. If not, see
# <http://www.gnu.org/licenses/>.

__author__ = 'Marco Galardini'
__version__ = '0.0.1'

def get_header(infile):
    '''Get the header of an Iris file'''
    return [l.strip() for (i,l) in zip(range(6), open(infile))]

def parse_iris(infile, platefile=None):
    '''Parse an Iris output

    Returns a Pandas dataframe.
    If a plate file is provided, a column with strain name will be added.
    '''
    import pandas as pd

    plate = pd.read_table(infile, skiprows=6)

    # Add the spots identifiers
    if platefile is not None:
        plate['id'] = [x[0] for x in sorted(parse_names(platefile),
                                     key=lambda x: (x[3][1], x[3][2]))]
        # Scar-tissue code (a multi-index is more complicated)
        #plate['name'] = [x[1] for x in sorted(parse_names(platefile),
        #                             key=lambda x: (x[3][1], x[3][2]))]
        #plate['nt'] = [x[2][0] for x in sorted(parse_names(platefile),
        #                             key=lambda x: (x[3][1], x[3][2]))]
        #plate.set_index(['id', 'name', 'nt'], inplace=True)
        plate.set_index('id', inplace=True)

    return plate

def parse_names(infile):
    '''Get the position and names for each strain
    
    Yields id, name, (p384, row, column), (p1536, row, column)
    
    For the 384 plate, a number is yielded instead of the column char
    '''
    alphabetical = 'ABCDEFGHIJKLMNOP'
    
    import csv
    with open(infile, 'rb') as tsvfile:
        reader = csv.reader(tsvfile, delimiter='\t')
        for r in reader:
            yield r[4], r[6], (r[7], alphabetical.index(r[9])+1, int(r[8])), (
                    r[10], int(r[11]), int(r[12]))

def fix_circularity(df,
        circularity=0.5,
        size=1200):
    '''Fix an Iris dataframe for circularity issues

    Parameters
    ----------
    df : a DataFrame generated from Iris
         "colony size" and "circularity" columns should be present;
         "colony color intensity" will also be corrected, if present
    circularity : circularity threshold
    size : size threshold; colonies above this size won't be fixed

    Returns
    -------
    df : the fixed DataFrame
    '''
    import numpy as np

    df.ix[(df['circularity'] < circularity) &
            (df['colony size'] < size),
            'colony size'] = 0
    try:
        df.ix[(df['circularity'] < circularity) &
                (df['colony size'] < size),
            'colony color intensity'] = np.nan
    except:
        pass
    
    return df

def remove_colonies(df, remove):
    '''Fix an Iris dataframe by removing colonies

    Parameters
    ----------
    df : dataframe generated from Iris
         "colony size" and "colony color intensity" columns should be present,
         as well as "row" and "column"
    remove: an iterable of (row, column) tuples to be removed
    
    Returns
    -------
    df : the fixed DataFrame
    '''
    import numpy as np

    for r, c in remove:
        df.ix[(df['row'] == r) &
                (df['column'] == c),
                'colony size'] = np.nan
        df.ix[(df['row'] == r) &
                (df['column'] == c),
                'colony color intensity'] = np.nan
    return df

def median(data):
    '''
    Get the median of the input data
    
    Works with columns extracted from a Pandas DataFrame
    '''
    import numpy as np

    data = np.ma.masked_array(data.as_matrix(),
                   np.isnan(data.as_matrix()))
    
    return np.ma.median(data)

def variance(data):
    '''
    Get the sample variance of the input data
    
    Works with columns extracted from a Pandas DataFrame
    '''
    import numpy as np
    
    data = np.ma.masked_array(data.as_matrix(),
                   np.isnan(data.as_matrix()))
    
    return np.ma.var(data)

def normalize_outer(df):
    '''
    Bring the outer colonies to the center median
    
    Takes in input a dataframe generated from an Iris file
    '''
    inner_median = median(df[(df.row > 2) &
                            (df.row < 31) &
                            (df.column > 2) &
                            (df.column < 47)]['colony size'])
    
    outer_median = median(df[(df.row < 3) |
                            (df.row > 30) |
                            (df.column < 3) |
                            (df.column > 46)]['colony size'])
    
    outer_size = df[(df.row < 3) |
                   (df.row > 30) |
                   (df.column < 3) |
                   (df.column > 46)]['colony size']
    
    df.ix[(df.row < 3) |
         (df.row > 30) |
         (df.column < 3) |
         (df.column > 46), 'colony size'] =  outer_size * (
                 inner_median/outer_median
                 )
    
    return df

def variance_jackknife(df,
        param='colony size',
        var_threshold=0.9):
    '''Fix an Iris dataframe by removing abnormaly variant colonies

    Parameters
    ----------
    df : dataframe generated from Iris
         the parameter on which the analysis is performed should be present,
         as well as "row", "column", "colony color intensity" and "colony size"
    param : parameter used for the variance analysis
    var_threshold : remove colonies which contribute to variance over
                    this threshold
    
    Returns
    -------
    df : the fixed DataFrame
    '''
    import numpy as np
    from copy import deepcopy

    # Copy the original dataframe
    m1 = deepcopy(df)

    # First bring the outer colonies to the inner median
    m = normalize_outer(df)
    
    strains = {x for x in m.index}
    for strain in strains:
        # Stop if there are less than 2 non-null points
        try:
            float(m.loc[strain, param])
            continue
        except:
            pass
        try:
            m.loc[strain,
                  param].dropna()
        except:
            continue
            
        spots = len(m.loc[strain,
            param].dropna())
            
        if spots < 3:
            continue
            
        discard = set()
        
        total_variance = variance(m.loc[
            strain].dropna()[param]) * (spots - 1)
        
        for s, r, c in zip(m.loc[strain].dropna()[param].as_matrix(),
                        m.loc[strain].dropna()['row'].as_matrix(),
                        m.loc[strain].dropna()['column'].as_matrix()):
            s_variance = variance(m[(m.row != r) &
                      (m.column != c)].loc[strain,
                          param])
            s_variance = np.power(s_variance, 2) * (spots - 2)
            if (total_variance-s_variance) > (var_threshold*total_variance):
                discard.add((r, c))
        
        # If we have to discard > 2 point it is likely a false positive
        # (i.e. two values are almost exactly the same)
        # Same if we have to discard 2 points, but there may be genuine 
        # contaminations/mistakes there
        if len(discard) > 2:
            continue
        
        # NaN the input parameter,
        # colony size and color
        # in the original dataframe
        for row, column in discard:
            m1.ix[(m1.row == row) &
                  (m1.column == column), param] = np.nan
            m1.ix[(m1.row == row) &
                  (m1.column == column),
                  'colony size'] = np.nan
            m1.ix[(m1.row == row) &
                  (m1.column == column),
                  'colony color intensity'] = np.nan

    return m1

def iqr(data):
    '''
    Compute the interquartile range
    
    Equivalent to R's IQR function
    Imortant: no NaN's should be present
    '''
    from scipy import stats

    Q1, Q3 = stats.mstats.mquantiles(data,
                        prob=[0.25, 0.75],
                        alphap=1,
                        betap=1)
    return Q3 - Q1

def mad(data, c=0.6745):
    '''
    Compute the MAD
    
    Equivalent to R's mad function
    Imortant: no NaN's should be present
    '''
    import numpy as np

    return np.ma.median(np.ma.fabs(data - np.ma.median(data))) / c

def iqr_norm(data):
    '''
    Normalize the data using the IQR
    (Inter-Quartile Range)
    
    Works with columns extracted from a Pandas DataFrame
    
    Equivalent to the R snippet used in the Typas lab
    (minor changes in the normalized score can be seen)
    '''
    import numpy as np
    from scipy import stats

    data = np.ma.masked_array(data.as_matrix(),
                   np.isnan(data.as_matrix()))
    
    iqr_std = stats.norm.ppf(0.75)*2
    
    return iqr_std * (data - np.median(data))/iqr(data)

def mad_norm(data):
    '''
    Normalize the data using the MAD
    (Mean Absolute Deviation)
    
    Works with columns extracted from a Pandas DataFrame
    
    Equivalent to the R snippet used in the Typas lab
    (minor changes in the normalized score can be seen)
    '''
    import numpy as np
    import math

    data = np.ma.masked_array(data.as_matrix(),
                   np.isnan(data.as_matrix()))
    
    mad_std = math.sqrt(2/math.pi)
    
    return mad_std * (data - np.ma.median(data))/mad(data)

