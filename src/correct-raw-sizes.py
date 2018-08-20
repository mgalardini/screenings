#!/usr/bin/env python
'''Apply surface correction and outer frame correction for colony sizes'''

import os
import sys
import numpy as np
import pandas as pd
import statsmodels.api as sm
from sklearn.preprocessing import PolynomialFeatures


def get_options():
    import argparse

    description = 'Apply standard colony size corrections on plates'
    parser = argparse.ArgumentParser(description=description)

    parser.add_argument('sizes',
                        help='Raw colony sizes file')
    parser.add_argument('info',
                        help='EMAP info directory')

    return parser.parse_args()


def surface_correction(values,
                       deg=2):
    poly = PolynomialFeatures(2).fit_transform(values[['row', 'column']].values)
    poly = np.linalg.qr(poly)[0][:,1:]
    x = sm.add_constant(poly)
    lm = sm.OLS(values['size'].values, x).fit()
    pred = lm.predict(x)
    yhat = values['size'] - pred + values['size'].dropna().mean()
    yhat[yhat < 0] = 0
    yhat[values['size'] == 0] = 0
    values['surface-corrected'] = yhat
    return values


def outer_frame_correction(df,
                           param='surface-corrected'):
    inner_median = df[(df.row > 2) &
                      (df.row < 31) &
                      (df.column > 2) &
                      (df.column < 47)][param].dropna().median()

    outer_median = df[(df.row < 3) |
                      (df.row > 30) |
                      (df.column < 3) |
                      (df.column > 46)][param].dropna().median()
    
    outer_size = df[(df.row < 3) |
                   (df.row > 30) |
                   (df.column < 3) |
                   (df.column > 46)][param]
    
    df['normalized'] = df[param]
    
    df.loc[df[(df.row < 3) |
              (df.row > 30) |
              (df.column < 3) |
              (df.column > 46)].index, 'normalized'] =  outer_size * (
                inner_median/outer_median)
    
    return df


if __name__ == "__main__":
    options = get_options()

    ifile = options.sizes
    einfo = options.info

    res = []
    for f in os.listdir(einfo):
        p = int(f.replace('plat', '').replace('.txt', ''))
        df = pd.read_table(os.path.join(einfo, f))
        for r, c, s in df[['Row', 'Column', 'Strain']].values:
            res.append((p, r, c, s))
    r = pd.DataFrame(res,
                     columns=['plate',
                              'row', 'column',
                              'strain'])
    r = r.set_index(['plate',
                     'row', 'column']).sort_index()

    m = pd.read_table(ifile,
                      header=[0, 1, 2, 3],
                      index_col=[0, 1])

    m = m.stack(level=-4).stack(level=-3).stack(level=-2).stack().reset_index()
    m.columns = ['row', 'column',
                 'plate', 'condition', 'replica', 'batch', 'size']
    m['plate'] = m['plate'].astype(int)
    m = m.set_index(['plate', 'row', 'column']).sort_index()

    m = m.join(r, how='outer')

    m['background'] = [x.split('_')[1]
                       for x in m['strain']]
    m['gene'] = [x.split('_')[0]
                 for x in m['strain']]

    m = m.reset_index()
    m = m.groupby(['plate', 'condition', 'replica', 'batch']).apply(surface_correction)
    m = m.groupby(['plate', 'condition', 'replica', 'batch']).apply(outer_frame_correction)

    m.to_csv(sys.stdout, sep='\t', index=False)
