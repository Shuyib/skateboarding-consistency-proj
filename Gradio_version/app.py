"""
This is a gradio app that helps me edit the excel data which has two sheets.

The first sheet has the data which will be edited and stored
The second sheet has the randomised data which will be the guide on how to fill the first sheet.
Once editing is done it can be synced with the DVC library to update the data in drive.

"""

import gradio as gr
import pandas as pd
import matplotlib.pyplot as plt

# load the data
df = pd.read_excel("../New skate project.xlsx", sheet_name="Sheet1")
df2 = pd.read_excel("../New skate project.xlsx", sheet_name="Sheet2")

# select the columns of interest
df = df.iloc[:, :28]
df2 = df2[["Random trick try", "Followed Y/N"]]

# drop the rows with all missing values
df2 = df2.dropna(how="all")


# convert to the right types
df["date_clean"] = pd.to_datetime(df["date"], errors="coerce")
df["date"] = pd.to_datetime(df["date"], errors="coerce")
df["board"] = df["board"].astype("category")
df["place"] = df["place"].astype("category")
df["C.virus"] = df["C.virus"].astype("category")
df["randomized"] = df["randomized"].astype("category")
# df = df.drop(columns=["date"])

df2 = df2.rename(columns={"Random trick try": "trick", "Followed Y/N": "followed"})
df2["followed"] = df2["followed"].astype("category")


# output a button to download the edited dataframe
def download(dataframe):
    dataframe.to_csv("edited_data.csv", index=False)
    return "edited_data.csv"


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


# draw line plots for the first 21 columns
# draw a line of the mean in the plot
def draw_line_plots(dataframe):
    # Clean backticks from the edited dataframe
    dataframe_cleaned = clean_dataframe_backticks(dataframe)
    
    # Keep the original df2 for second sheet data
    dataframe2 = df2
    
    # Create plots using the cleaned, edited dataframe
    fig, ax = plt.subplots(7, 3, figsize=(20, 20))  # 7 rows and 3 columns
    ax = ax.ravel()  # flatten the 2D array to 1D array
    
    # Get numeric columns for plotting (first 21 or available columns)
    numeric_cols = []
    for col in dataframe_cleaned.columns:
        if col not in ['date', 'date_clean', 'place', 'location', 'board', 'C.virus', 'randomized']:
            if pd.api.types.is_numeric_dtype(dataframe_cleaned[col]):
                numeric_cols.append(col)
    
    # Limit to first 21 numeric columns or available columns
    plot_cols = numeric_cols[:min(21, len(numeric_cols))]
    
    for i, col in enumerate(plot_cols):
        if i >= 21:  # Safety check
            break
            
        # Handle potential NaN values
        col_data = dataframe_cleaned[col].dropna()
        if len(col_data) > 0:
            ax[i].plot(col_data, label=col)  # Plot the data in the column
            ax[i].axhline(
                col_data.mean(), color="red", linestyle="--", label="mean"
            )  # add a horizontal line of the mean
            ax[i].set_title(col)  # Add title to the plot
            ax[i].legend()  # Add legend
            ax[i].grid(True)  # Add gridlines
            ax[i].set_xlabel("Index")  # Add x-axis label
            ax[i].set_ylabel("Value")  # Add y-axis label
            # add sum of plot as text in bold in the plot with color green
            ax[i].text(
                0.5,
                0.5,
                "Sum: " + str(col_data.sum()),
                horizontalalignment="center",
                verticalalignment="center",
                transform=ax[i].transAxes,  # transform the text to the axis
                fontsize=12,
                color="green",
                weight="bold",
            )

    plt.tight_layout()
    plt.savefig("line_plots.png")
    plot = ["line_plots.png"]
    
    # Download the cleaned, edited dataframe instead of original
    download(dataframe_cleaned)
    
    # Return the cleaned, edited dataframe and original second sheet
    return dataframe_cleaned, dataframe2, plot, "edited_data.csv"


# create the gradio interface, add button to download the edited dataframe
gr.Interface(
    fn=draw_line_plots,
    inputs=gr.DataFrame(type="pandas", headers=list(df.columns), label="Data"),
    outputs=[
        gr.DataFrame(type="pandas", label="Edited Data (Cleaned)"),
        gr.DataFrame(type="pandas", label="Guide Data (Sheet2)"),
        gr.Gallery(type="file", label="Line Plots"),
        gr.File(label="Download Edited Data"),
    ],
    title="Skate Data Editor",
    description="Edit the data and download the edited dataframe. Backticks (`) will be automatically removed from entries.",
    examples=[df.tail(10), df2.tail(10)],
).launch()
