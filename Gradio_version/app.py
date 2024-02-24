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

# find the sum of the columns and add it to the dataframe
# columnwise sum
# df["total"] = df.iloc[:, 1:21].sum(axis=1)

# columwise probability of the trick
# df["prob"] = df.iloc[:, 1:21].sum(axis=1) / 20


# get the first 21 columns names
# make a dataframe with columns and the trick names
trick_names = df.columns[:21]
trick_names = pd.DataFrame(trick_names, columns=["trick_names"])

# merge the trick names with the second dataframe
df3 = pd.merge(df2, trick_names, left_on="trick", right_on="trick_names", how="left")


# output a button to download the edited dataframe
def download(dataframe):
    dataframe.to_csv("edited_data.csv", index=False)
    return "edited_data.csv"


# draw line plots for the first 21 columns
# draw a line of the mean in the plot
def draw_line_plots(dataframe):
    dataframe = df
    dataframe2 = df2
    fig, ax = plt.subplots(7, 3, figsize=(20, 20))
    ax = ax.ravel()
    for i, col in enumerate(dataframe.columns[:21]):
        ax[i].plot(dataframe[col], label=col)
        ax[i].axhline(dataframe[col].mean(), color="red", linestyle="--", label="mean")
        ax[i].set_title(col)
        ax[i].legend()
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
            transform=ax[i].transAxes,
            fontsize=12,
            color="green",
            weight="bold",
        )
    plt.tight_layout()
    plt.savefig("line_plots.png")
    plot = ["line_plots.png"]
    return dataframe, dataframe2, plot


# create the gradio interface, add button to download the edited dataframe
gr.Interface(
    fn=draw_line_plots,
    inputs=gr.DataFrame(type="pandas", headers=list(df.columns), label="Data"),
    outputs=[
        gr.DataFrame(type="pandas", headers=list(df.columns), label="Edited Data"),
        gr.DataFrame(type="pandas", headers=list(df2.columns), label="Guide Data"),
        gr.Gallery(type="file", label="Line Plots"),
    ],
    title="Skate Data Editor",
    description="Edit the data and download the edited dataframe",
    examples=[df.tail(10), df2.tail(10)],
).launch()
