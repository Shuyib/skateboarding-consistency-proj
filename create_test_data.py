#!/usr/bin/env python3
"""Create test data to understand the backtick issue."""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta

# Create test data that mimics the structure mentioned in the app
dates = pd.date_range('2024-01-01', periods=30, freq='D')
data = {
    'date': dates,
    'place': ['park', 'street', 'ramp'] * 10,
    'board': ['Element', 'Powell', 'Santa Cruz'] * 10,
    'C.virus': ['No', 'Yes', 'No'] * 10,
    'randomized': [1, 0, 1] * 10,
    # Sample trick columns (first 21 as mentioned in the code)
    'kickflip': np.random.randint(0, 5, 30),
    'heelflip': np.random.randint(0, 5, 30),
    'ollie': np.random.randint(0, 8, 30),
    'tre.flip': np.random.randint(0, 3, 30),
    'bs.180': np.random.randint(0, 6, 30),
    'fs.180': np.random.randint(0, 6, 30),
    'pop.shove': np.random.randint(0, 7, 30),
    'bs.shove': np.random.randint(0, 7, 30),
    'fs.shove': np.random.randint(0, 5, 30),
    'varial.flip': np.random.randint(0, 4, 30),
    'hardflip': np.random.randint(0, 2, 30),
    'inward.heel': np.random.randint(0, 2, 30),
    'f.fs.shove': np.random.randint(0, 5, 30),
    'f.bigspin': np.random.randint(0, 3, 30),
    'nollie': np.random.randint(0, 4, 30),
    'nollie.fs.180': np.random.randint(0, 3, 30),
    'switch.ollie': np.random.randint(0, 3, 30),
    'switch.kickflip': np.random.randint(0, 2, 30),
    'manual': np.random.randint(0, 6, 30),
    'nose.manual': np.random.randint(0, 5, 30),
    'boardslide': np.random.randint(0, 4, 30),
}

# Create DataFrame
df = pd.DataFrame(data)

# Create second sheet with randomized data
df2_data = {
    'Random trick try': ['kickflip', 'heelflip', 'ollie', 'tre.flip', 'bs.180'] * 6,
    'Followed Y/N': ['Y', 'N', 'Y', 'Y', 'N'] * 6
}
df2 = pd.DataFrame(df2_data)

# Save to Excel file with two sheets
with pd.ExcelWriter('New skate project.xlsx', engine='openpyxl') as writer:
    df.to_excel(writer, sheet_name='Sheet1', index=False)
    df2.to_excel(writer, sheet_name='Sheet2', index=False)

print("Created test Excel file: New skate project.xlsx")
print("Sheet1 shape:", df.shape)
print("Sheet2 shape:", df2.shape)
print("Sheet1 columns:", list(df.columns))