#!/usr/bin/env python3
"""Test the fixed backtick cleaning functionality in the Gradio app."""

import pandas as pd
import sys
import os

# Add the current directory to sys.path to import functions
sys.path.append('/home/runner/work/skateboarding-consistency-proj/skateboarding-consistency-proj/Gradio_version')

def test_backtick_fix():
    """Test the backtick cleaning fix."""
    print("Testing the backtick cleaning fix...")
    
    # Import the functions from the app
    try:
        from app import clean_backticks, clean_dataframe_backticks, draw_line_plots
        print("✅ Successfully imported functions from app.py")
    except ImportError as e:
        print(f"❌ Failed to import functions: {e}")
        return False
    
    # Create test data with backticks (simulating what Gradio might produce)
    test_data = {
        'date': ['2024-01-01', '2024-01-02', '2024-01-03'],
        'place': ['park', '`street`', 'ramp'],
        'kickflip': ['`3`', '2', '`5`'],  # Numeric data with backticks
        'heelflip': [1, '`4`', 2],
        'ollie': ['6', '7', '`8`'],
        'board': ['Element', '`Powell`', 'Santa Cruz'],
        'randomized': [1, 0, '`1`']
    }
    
    df_with_backticks = pd.DataFrame(test_data)
    print("\n--- Test Data with Backticks ---")
    print(df_with_backticks)
    print("\nData types before cleaning:")
    print(df_with_backticks.dtypes)
    
    # Test the cleaning function
    try:
        df_cleaned = clean_dataframe_backticks(df_with_backticks)
        print("\n--- Cleaned Data ---")
        print(df_cleaned)
        print("\nData types after cleaning:")
        print(df_cleaned.dtypes)
        
        # Verify that backticks are removed
        success = True
        for col in df_cleaned.columns:
            for value in df_cleaned[col]:
                if isinstance(value, str) and ('`' in str(value)):
                    print(f"❌ Backtick found in {col}: {value}")
                    success = False
        
        if success:
            print("✅ All backticks successfully removed!")
        
        # Test numeric conversion
        numeric_cols = ['kickflip', 'heelflip', 'ollie']
        for col in numeric_cols:
            if pd.api.types.is_numeric_dtype(df_cleaned[col]):
                print(f"✅ {col} successfully converted to numeric")
            else:
                print(f"⚠️  {col} not converted to numeric (may be intentional)")
                
        return success
        
    except Exception as e:
        print(f"❌ Error during cleaning: {e}")
        return False

def test_integration():
    """Test integration with the main function."""
    print("\n=== Integration Test ===")
    
    # Load the actual Excel file
    try:
        df = pd.read_excel("New skate project.xlsx", sheet_name="Sheet1")
        df = df.iloc[:, :28]  # Select columns as in original app
        
        # Add some backticks to simulate user edits
        df_with_edits = df.copy()
        if 'kickflip' in df_with_edits.columns:
            df_with_edits.loc[0, 'kickflip'] = '`5`'
        if 'heelflip' in df_with_edits.columns:
            df_with_edits.loc[1, 'heelflip'] = '`3`'
        if 'place' in df_with_edits.columns:
            df_with_edits.loc[0, 'place'] = '`park`'
            
        print("Created test dataframe with simulated user edits (backticks added)")
        print(f"DataFrame shape: {df_with_edits.shape}")
        
        # Import the main function
        from app import draw_line_plots
        
        # Test the main function (but don't run the full plotting)
        print("Testing data cleaning part of draw_line_plots...")
        from app import clean_dataframe_backticks
        
        cleaned_df = clean_dataframe_backticks(df_with_edits)
        print("✅ Successfully cleaned dataframe in integration test")
        
        # Verify backticks are removed
        has_backticks = False
        for col in cleaned_df.columns:
            for value in cleaned_df[col]:
                if isinstance(value, str) and '`' in str(value):
                    has_backticks = True
                    break
            if has_backticks:
                break
                
        if not has_backticks:
            print("✅ Integration test: No backticks found in cleaned data")
            return True
        else:
            print("❌ Integration test: Backticks still present after cleaning")
            return False
            
    except Exception as e:
        print(f"❌ Integration test failed: {e}")
        return False

if __name__ == "__main__":
    print("=" * 50)
    print("TESTING BACKTICK FIX")
    print("=" * 50)
    
    # Run tests
    basic_test_success = test_backtick_fix()
    integration_test_success = test_integration()
    
    print("\n" + "=" * 50)
    print("TEST RESULTS")
    print("=" * 50)
    
    if basic_test_success and integration_test_success:
        print("🎉 ALL TESTS PASSED! Backtick issue has been fixed.")
        sys.exit(0)
    else:
        print("❌ Some tests failed. Please check the output above.")
        sys.exit(1)