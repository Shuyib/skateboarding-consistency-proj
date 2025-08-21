#!/usr/bin/env python3
"""Test script to understand and reproduce the backtick issue in Gradio DataFrame component."""

import pandas as pd
import numpy as np

def test_backtick_issue():
    """Test to understand how backticks might be introduced in data entries."""
    
    # Create test data that might cause backtick issues
    test_data = {
        'name': ['Alice', 'Bob', 'Charlie'],
        'score': [10, 20, 30],
        'comments': ['Good job', 'Needs work', 'Excellent']
    }
    
    df = pd.DataFrame(test_data)
    print("Original DataFrame:")
    print(df)
    print("\nDataFrame dtypes:")
    print(df.dtypes)
    
    # Simulate what might happen when data goes through Gradio
    # Test different scenarios where backticks might be added
    
    # Scenario 1: Data with quotes
    df_with_quotes = df.copy()
    df_with_quotes.loc[0, 'comments'] = "Said 'hello'"
    print("\n--- Scenario 1: Data with quotes ---")
    print(df_with_quotes)
    
    # Scenario 2: Data with backticks already present
    df_with_backticks = df.copy()
    df_with_backticks.loc[1, 'comments'] = "`important note`"
    print("\n--- Scenario 2: Data with existing backticks ---")
    print(df_with_backticks)
    
    # Scenario 3: Numeric data as strings with backticks
    df_numeric_strings = df.copy()
    df_numeric_strings.loc[0, 'score'] = "`15`"  # This could happen if user edits
    print("\n--- Scenario 3: Numeric data with backticks ---")
    print(df_numeric_strings)
    print("Dtypes after backtick addition:")
    print(df_numeric_strings.dtypes)
    
    # Test cleaning function
    def clean_backticks(value):
        """Remove backticks from the beginning and end of string values."""
        if isinstance(value, str):
            # Remove backticks from start and end
            if value.startswith('`') and value.endswith('`') and len(value) > 2:
                return value[1:-1]
            elif value.startswith('`'):
                return value[1:]
            elif value.endswith('`'):
                return value[:-1]
        return value
    
    def clean_dataframe_backticks(df):
        """Clean backticks from all string columns in the dataframe."""
        df_cleaned = df.copy()
        for col in df_cleaned.columns:
            if df_cleaned[col].dtype == 'object':  # String columns
                df_cleaned[col] = df_cleaned[col].apply(clean_backticks)
            # Handle numeric columns that might have been converted to strings
            elif col != 'date' and col != 'date_clean':  # Avoid date columns
                # Try to convert back to numeric after cleaning
                if df_cleaned[col].dtype == 'object':
                    cleaned_series = df_cleaned[col].apply(clean_backticks)
                    # Try to convert to numeric
                    try:
                        numeric_series = pd.to_numeric(cleaned_series, errors='ignore')
                        df_cleaned[col] = numeric_series
                    except:
                        df_cleaned[col] = cleaned_series
        return df_cleaned
    
    # Test the cleaning function
    print("\n--- Testing backtick cleaning ---")
    df_to_clean = df_numeric_strings.copy()
    print("Before cleaning:")
    print(df_to_clean)
    print("Dtypes before cleaning:")
    print(df_to_clean.dtypes)
    
    df_cleaned = clean_dataframe_backticks(df_to_clean)
    print("\nAfter cleaning:")
    print(df_cleaned)
    print("Dtypes after cleaning:")
    print(df_cleaned.dtypes)
    
    return clean_dataframe_backticks

if __name__ == "__main__":
    clean_function = test_backtick_issue()
    print("\nBacktick cleaning function created successfully!")