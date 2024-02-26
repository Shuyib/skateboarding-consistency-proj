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


# draw line plots for the first 21 columns
# draw a line of the mean in the plot
def draw_line_plots(dataframe):
    dataframe = df
    dataframe2 = df2
    fig, ax = plt.subplots(7, 3, figsize=(20, 20))  # 7 rows and 3 columns
    ax = ax.ravel()  # flatten the 2D array to 1D array
    for i, col in enumerate(dataframe.columns[:21]):
        ax[i].plot(dataframe[col], label=col)  # Plot the data in the column
        ax[i].axhline(
            dataframe[col].mean(), color="red", linestyle="--", label="mean"
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
            "Sum: " + str(dataframe[col].sum()),
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
    download(df)
    return dataframe, dataframe2, plot, "edited_data.csv"  # three outputs


# create the gradio interface, add button to download the edited dataframe
gr.Interface(
    fn=draw_line_plots,
    inputs=gr.DataFrame(type="pandas", headers=list(df.columns), label="Data"),
    outputs=[
        gr.Gallery(type="file", label="Line Plots"),
        gr.File(label="Download Edited Data"),
    ],
    title="Skate Data Editor",
    description="Edit the data and download the edited dataframe",
    examples=[df.tail(10), df2.tail(10)],
).launch()
