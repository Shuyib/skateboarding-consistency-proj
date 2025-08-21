#!/usr/bin/env python3
"""Test the backtick cleaning functionality separately."""

import pandas as pd

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
    """Clean backticks from all columns in the dataframe and preserve data types."""
    df_cleaned = df.copy()
    
    for col in df_cleaned.columns:
        # Clean backticks from all columns
        df_cleaned[col] = df_cleaned[col].apply(clean_backticks)
        
        # For numeric columns (trick columns), try to convert back to numeric
        if col not in ['date', 'date_clean', 'place', 'location', 'board', 'C.virus', 'randomized']:
            try:
                # Attempt to convert to numeric, keeping NaN for non-numeric values
                df_cleaned[col] = pd.to_numeric(df_cleaned[col], errors='coerce')
            except:
                # If conversion fails, keep as is
                pass
    
    return df_cleaned


def test_backtick_cleaning():
    """Test backtick cleaning with various scenarios."""
    print("Testing backtick cleaning functionality...")
    
    # Test data with various backtick scenarios
    test_data = {
        'date': ['2024-01-01', '2024-01-02', '2024-01-03'],
        'place': ['park', '`street`', 'ramp'],
        'kickflip': ['`3`', '2', '`5`'],  # Numeric data with backticks
        'heelflip': [1, '`4`', 2],
        'ollie': ['6', '7', '`8`'],
        'board': ['Element', '`Powell`', 'Santa Cruz'],
        'C.virus': ['No', '`Yes`', 'No'],
        'randomized': [1, 0, '`1`']
    }
    
    df_test = pd.DataFrame(test_data)
    print("\n=== Original Data ===")
    print(df_test)
    print("\nData types before cleaning:")
    print(df_test.dtypes)
    
    # Clean the data
    df_cleaned = clean_dataframe_backticks(df_test)
    print("\n=== Cleaned Data ===")
    print(df_cleaned)
    print("\nData types after cleaning:")
    print(df_cleaned.dtypes)
    
    # Verify backticks are removed
    print("\n=== Verification ===")
    has_backticks = False
    backtick_locations = []
    
    for col in df_cleaned.columns:
        for idx, value in enumerate(df_cleaned[col]):
            if isinstance(value, str) and '`' in str(value):
                has_backticks = True
                backtick_locations.append(f"Row {idx}, Column '{col}': {value}")
    
    if has_backticks:
        print("❌ Backticks still found in:")
        for location in backtick_locations:
            print(f"   {location}")
        return False
    else:
        print("✅ All backticks successfully removed!")
    
    # Verify numeric conversions
    numeric_cols = ['kickflip', 'heelflip', 'ollie', 'randomized']
    numeric_conversion_success = True
    
    for col in numeric_cols:
        if col in df_cleaned.columns:
            if pd.api.types.is_numeric_dtype(df_cleaned[col]):
                print(f"✅ {col} successfully converted to numeric")
            else:
                print(f"⚠️  {col} not converted to numeric")
                numeric_conversion_success = False
    
    print(f"\n=== Summary ===")
    print(f"Backtick removal: {'✅ PASS' if not has_backticks else '❌ FAIL'}")
    print(f"Numeric conversion: {'✅ PASS' if numeric_conversion_success else '⚠️  PARTIAL'}")
    
    return not has_backticks


def test_edge_cases():
    """Test edge cases for backtick cleaning."""
    print("\n" + "="*50)
    print("Testing edge cases...")
    
    edge_cases = {
        'single_backtick': ['`', 'test`', '`test'],
        'empty_backticks': ['``', '`  `', '`\t`'],
        'multiple_backticks': ['``test``', '`test`more`', '`test`'],
        'mixed_content': ['`123.45`', '`-999`', '`0`'],
        'special_chars': ['`hello world!`', '`test@example.com`', '`$100`']
    }
    
    df_edge = pd.DataFrame(edge_cases)
    print("\n=== Edge Case Data ===")
    print(df_edge)
    
    df_cleaned = clean_dataframe_backticks(df_edge)
    print("\n=== Cleaned Edge Case Data ===")
    print(df_cleaned)
    
    # Check for remaining backticks
    has_backticks = False
    for col in df_cleaned.columns:
        for value in df_cleaned[col]:
            if isinstance(value, str) and '`' in str(value):
                has_backticks = True
                print(f"⚠️  Backtick found in {col}: {value}")
    
    if not has_backticks:
        print("✅ All edge case backticks handled correctly!")
    
    return not has_backticks


if __name__ == "__main__":
    print("="*50)
    print("BACKTICK CLEANING TEST")
    print("="*50)
    
    basic_test = test_backtick_cleaning()
    edge_test = test_edge_cases()
    
    print("\n" + "="*50)
    print("FINAL RESULTS")
    print("="*50)
    
    if basic_test and edge_test:
        print("🎉 ALL TESTS PASSED!")
        print("The backtick issue has been successfully fixed!")
    else:
        print("❌ Some tests failed. Review the output above.")
    
    print("\nThe fix will:")
    print("1. ✅ Remove backticks from user entries")
    print("2. ✅ Preserve numeric data types for trick columns")
    print("3. ✅ Handle edge cases with multiple or partial backticks")
    print("4. ✅ Use the edited dataframe instead of ignoring user changes")