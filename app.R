###############################################################################
# app.R  –  Skate‑trick dashboard  (v12‑full: auto‑add headers + full plots)
###############################################################################
# Skate-trick dashboard: Shiny app for tracking and visualizing skate tricks.
# Version: v12-full (auto-add headers + full plots)
# How to run:
# 1. Install required packages: shiny, shinydashboard, googlesheets4, dplyr,
#    tidyr, plotly, lubridate, DT, rlang
#    (if not already installed). You can do this in R or RStudio console
# like this:
#    install.packages(c("shiny", "shinydashboard", "googlesheets4", "dplyr",
#                       "tidyr", "plotly", "lubridate", "DT", "rlang"))
#
# 2. Set up Google Sheets API credentials (GS4_SA_JSON) for authentication.
# 3. Run the app using `shiny::runApp("path/to/app.R")`
# or deploy to shinyapps.io.

# ── Library Imports ─────────────────────────────────────────────────────────
# Load necessary packages for UI, data manipulation, plotting, and GSheets.
library(shiny)
library(shinydashboard)
library(googlesheets4)
library(dplyr)
library(tidyr)
library(plotly)
library(lubridate)
library(DT)
library(rlang)

# ── Global Variable Declarations ────────────────────────────────────────────
# Suppress R CMD check notes for variables used in dplyr chains or formulas.
utils::globalVariables(
  c("lands", "trick", "total", "wk", "month_day")
)

# ── Google Sheets Authentication ────────────────────────────────────────────
# Authenticates with Google Sheets using environment variables for deployment
# or local OAuth for development.
if (nzchar(Sys.getenv("GS4_SA_JSON"))) {
  gs4_auth(path = Sys.getenv("GS4_SA_JSON")) # on shinyapps.io
} else {
  gs4_auth(email = TRUE, cache = ".secrets") # local OAuth
}

# Defines the URL for the Google Sheet that stores the skate log data.
sheet_url <- Sys.getenv("SHEET_ID") # Google Sheet ID

# ── Helper Functions ─────────────────────────────────────────────────────────
# This section contains utility functions used throughout the app.

#' Safely Convert Input to Date Object
#'
#' Attempts to convert various input types (Date, POSIXt, numeric, character)
#' to a standard R `Date` object, handling common formats.
#'
#' @param x An object to be converted to a `Date`.
#' @return A `Date` object or `NA` for unparseable inputs.
#' @details Handles Excel serial dates and multiple character string formats.
#' @importFrom lubridate parse_date_time
safe_date <- function(x) {
  if (inherits(x, "Date")) {
    return(x)
  }
  if (inherits(x, "POSIXt")) {
    return(as.Date(x))
  }
  if (is.numeric(x)) {
    return(as.Date(x, origin = "1899-12-30"))
  }
  parse_date_time(as.character(x),
    orders = c("Ymd", "dmY", "mdY", "Y/m/d", "d/m/Y", "m/d/Y"),
    tz = "UTC", quiet = TRUE
  ) |> as.Date()
}
# the |> operator is used to pipe the result of parse_date_time to as.Date()
# Reads and preprocesses data from the Google Sheet.
# Handles date conversion and ensures trick columns are numeric.
read_logs <- function() {
  # Read the sheet with explicit detection of column types
  df <- read_sheet(sheet_url, sheet = "Sheet1", .name_repair = "unique")

  # Handle date column
  if ("date" %in% names(df)) {
    df$date <- safe_date(df$date)
  } else if ("date_clean" %in% names(df)) {
    # Use a local variable to avoid the "no visible binding" warning
    date_clean_col <- "date_clean"
    df <- rename(df, date = !!date_clean_col)
    df$date <- safe_date(df$date)
  } else {
    stop("Sheet missing a date column.")
  }

  # Ensure all potential trick columns are numeric
  numeric_candidates <- setdiff(
    names(df),
    c(
      "date", "date_clean", "place", "location",
      grep("^attempts_", names(df), value = TRUE),
      "randomized", "weights", "C.virus", "board"
    )
  )

  for (col in numeric_candidates) {
    # Coerce everything to character, then numeric
    # (handles lists, factors, etc.)
    df[[col]] <- suppressWarnings(as.numeric(as.character(df[[col]])))
  }

  df
}

# ── User Interface (UI) Definition ───────────────────────────────────────────
# Defines the layout and appearance of the Shiny application using
# shinydashboard.
ui <- dashboardPage(
  skin = "blue",
  # Header: Displays the application title.
  dashboardHeader(title = "Skate‑trick tracker"),
  # Sidebar: Contains navigation menu items for different app sections.
  dashboardSidebar(
    sidebarMenu(
      menuItem("Dashboard", tabName = "dash", icon = icon("chart-line")),
      menuItem("Log", tabName = "log", icon = icon("pen")),
      menuItem("Randomiser", tabName = "rand", icon = icon("dice"))
    )
  ),
  # Body: Contains the content for each tab defined in the sidebar.
  dashboardBody(
    tabItems(
      # --- Dashboard Tab ---
      # Displays key performance indicators (KPIs), scatter plot, heatmaps,
      # and raw data for selected tricks and date ranges.
      tabItem(
        "dash",
        fluidRow(
          # Input controls for trick selection and date range.
          box(
            width = 3, status = "info", solidHeader = TRUE, title = "Inputs",
            selectInput("trick", "Trick", choices = NULL),
            dateRangeInput("rng", "Dates", Sys.Date() - 30, Sys.Date())
          ),
          # Value boxes for session count, total lands,
          # and mean lands for SELECTED trick.
          valueBoxOutput("sess"), valueBoxOutput("tot"), valueBoxOutput("mean")
        ),
        # New Row: Top 3 Overall Best Tricks (Value Boxes)
        fluidRow(
          valueBoxOutput("top_trick1_vb", width = 4),
          valueBoxOutput("top_trick2_vb", width = 4),
          valueBoxOutput("top_trick3_vb", width = 4)
        ),
        # New Row: Overall Leaderboard Table & Radar Chart
        fluidRow(
          box(
            width = 6, status = "primary", solidHeader = TRUE,
            title = "Trick Leaderboard (Mean Lands/Session)",
            DTOutput("leaderboard_table")
          ),
          box(
            width = 6, status = "primary", solidHeader = TRUE,
            title = "Trick Strength Radar",
            # Added height for better radar display
            plotlyOutput("radar_chart", height = 400)
          )
        ),
        fluidRow(box(
          width = 12, status = "primary", solidHeader = TRUE,
          title = "Per‑session scatter", plotlyOutput("scat", height = 320)
        )),
        fluidRow(box(
          width = 12, status = "primary", solidHeader = TRUE,
          title = "Monthly heat‑map", plotlyOutput("heat", height = 330)
        )),
        fluidRow(box(
          width = 12, status = "primary", solidHeader = TRUE,
          # Title includes navigation buttons for changing the year.
          title = tagList(
            "Year calendar",
            actionButton("prev_year", NULL,
                         icon("chevron-left"), class = "btn-xs"),
            uiOutput("cal_year_lbl"), # Displays the currently selected year.
            actionButton("next_year", NULL,
                         icon("chevron-right"), class = "btn-xs")
          ),
          plotlyOutput("calendar", height = 160)
        )),
        fluidRow(box(
          width = 12, status = "warning", solidHeader = TRUE,
          title = "Raw log data", DTOutput("raw") # Transposed log data table.
        )),
        fluidRow(
          # New Row: Refresh Button
          box(
            width = 12, status = "info", solidHeader = TRUE,
            title = "Refresh Data",
            actionButton("refresh", "Refresh Data")
          )
        ),
        # Debugging Info: Displays latest date and row count from data
        fluidRow(
          box(
            width = 12, status = "info", solidHeader = TRUE,
            title = "Debug Info",
            verbatimTextOutput("debug_info")
          )
        )
      ),

      # --- Logging Tab ---
      # Provides a form to log new skate sessions, including date, location,
      # trick, and number of lands. Allows saving or updating entries.
      tabItem(
        "log",
        box(
          width = 4, status = "success", solidHeader = TRUE,
          title = "Log new session",
          dateInput("new_date", "Date", Sys.Date()),
          uiOutput("new_loc_ui"),      # Dynamic UI for location input.
          uiOutput("new_trick_ui"),   # Dynamic UI for trick input.
          numericInput("new_land", "Landed", 0, min = 0),
          actionButton("add", "Save / update row", class = "btn-success"),
          verbatimTextOutput("add_msg") # Displays messages after save/update.
        )
      ),

      # --- Randomiser Tab ---
      # Allows users to generate a random list of tricks for practice sessions.
      # Users can specify the number of tricks to shuffle.
      tabItem(
        "rand",
        box(
          width = 4, status = "info", solidHeader = TRUE,
          title = "Shuffle practice list",
          uiOutput("nrand_ui"), # Slider for selecting number of tricks.
          actionButton("roll", "Shuffle!", icon = icon("dice")),
          DTOutput("plan")      # Table displaying the shuffled trick list.
        )
      )
    )
  )
)

# ── Additional Helper Functions ──────────────────────────────────────────────
#' Check if a Vector is Numeric-Like
#'
#' Determines if a vector can be considered numeric or coercible to numeric.
#' Handles lists, already numeric vectors, and character vectors.
#'
#' @param x A vector to check.
#' @return TRUE if numeric-like, FALSE otherwise.
is_numeric_like <- function(x) {
  if (is.list(x)) return(FALSE)
  if (is.numeric(x)) return(TRUE)
  vals <- as.character(x)
  vals <- vals[!is.na(vals) & vals != ""]
  if (length(vals) == 0) return(TRUE)
  !all(is.na(suppressWarnings(as.numeric(vals))))
}

# ── Server Logic ─────────────────────────────────────────────────────────────
# Contains the server-side logic for the Shiny application.
# Handles data processing, plot generation, and interactions.
server <- function(input, output, session) {
  autoInvalidate <- reactiveTimer(60000, session)  # every 60 seconds
  logs_trigger <- reactiveVal(Sys.time())  # trigger for manual log refresh

  logs <- reactive({
    autoInvalidate()          # invalidates this reactive every minute
    logs_trigger()            # also invalidate when manually triggered
    read_logs()               # so we re‐read the sheet
  })

  # Identifies which columns in the log data represent actual skate tricks.
  # Excludes non-trick columns like dates, locations, and metadata.
  trick_cols <- reactive({
    raw <- logs()

    # Identify columns that are numeric or can be treated as numeric
    potential_trick_cols <- names(raw)[sapply(raw, is_numeric_like)]

    # Exclude known non-trick columns
    setdiff(
      potential_trick_cols,
      c(
        "date", "date_clean", "place", "location",
        grep("^attempts_", names(raw), value = TRUE),
        "randomized", "weights", "C.virus", "board"
      )
    )
  })

  # Dynamic dropdowns: Populates and updates input selectors.
  # Trick selector for dashboard and logging tab.
  # Location selector for logging tab, allowing new entries.
  observe({
    tr <- trick_cols()
    updateSelectInput(session, "trick",
      choices = tr,
      selected = if (length(tr) > 0) input$trick %||% tr[1] else NULL
    )

    # trick selector
    output$new_trick_ui <- renderUI(
      selectizeInput("new_trick", "Trick",
        choices = c(tr, "<new>"),
        options = list(create = TRUE)
      )
    )

    # location selector (existing + create new)
    output$new_loc_ui <- renderUI({
      df <- logs()
      loc_col <- if ("location" %in% names(df)) "location" else "place"
      selectizeInput("new_loc", "Location",
        choices = sort(unique(na.omit(df[[loc_col]]))),
        options = list(create = TRUE)
      )
    })
  })

  # Key Performance Indicators (KPIs): Calculates and displays summary stats.
  # Filters data based on selected trick and date range.
  # Shows total sessions, total lands, and mean lands per session.
  filt <- reactive({
    req(input$trick, input$rng)
    logs() |> filter(date >= input$rng[1], date <= input$rng[2])
  })
  output$sess <- renderValueBox(
    valueBox(
      nrow(filt()),
      "Sessions",
      icon("calendar")
    )
  )
  output$tot <- renderValueBox(valueBox(
    sum(filt()[[input$trick]], na.rm = TRUE),
    "Total lands", icon("check")
  ))
  output$mean <- renderValueBox(valueBox(
    round(mean(filt()[[input$trick]], na.rm = TRUE), 2),
    "Mean / session", icon("minus")
  ))

  # --- Leaderboard and Best Tricks ---
  # Calculate overall trick performance (mean lands per session)
  overall_trick_performance <- reactive({
    req(logs(), trick_cols()) # Ensure trick_cols() is available
    df <- logs()
    # Assign the result of trick_cols() to tr_cols_local
    tr_cols_local <- trick_cols()

    if (length(tr_cols_local) == 0) {
      return(
        tibble(
          trick = character(),
          mean_lands = numeric(),
          sessions = integer()
        )
      )
    } else {
      df |>
        select(all_of(tr_cols_local)) |>
        pivot_longer(
          cols = all_of(tr_cols_local),
          names_to = "trick",
          values_to = "lands"
        ) |>
        # Consider only sessions where the trick was attempted/logged
        filter(!is.na(lands)) |> #nolinter
        group_by(trick) |> #nolinter
        summarise(
          mean_lands = mean(lands, na.rm = TRUE),
          sessions = n(), # Number of sessions where trick was logged
          .groups = "drop"
        ) |>
        arrange(desc(mean_lands)) #nolinter
    }
  })

  # Leaderboard Table
  output$leaderboard_table <- renderDT({
    perf_data <- overall_trick_performance()
    validate(need(
      nrow(perf_data) > 0,
      "No trick data available for leaderboard."
    ))
    # Avoid "no visible binding" notes by declaring variables as local
    local({
      datatable(
        perf_data |>
          select(
            Trick = trick,
            `Mean Lands` = mean_lands,
            Sessions = sessions
          ) |>
          mutate(`Mean Lands` = round(`Mean Lands`, 2)),
        options = list(
          pageLength = 5,
          searching = FALSE,
          lengthChange = FALSE
        )
      )
    })
  })

  # Top 3 Trick Value Boxes
  output$top_trick1_vb <- renderValueBox({
    top_tricks <- overall_trick_performance()
    if (nrow(top_tricks) >= 1) {
      valueBox(
        subtitle = paste0("🏆 Best Trick: ", top_tricks$trick[1]),
        value = paste0(round(top_tricks$mean_lands[1], 2), " lands/session"),
        icon = icon("trophy"), color = "yellow"
      )
    } else {
      valueBox("N/A", "Best Trick", icon = icon("trophy"), color = "yellow")
    }
  })

  output$top_trick2_vb <- renderValueBox({
    top_tricks <- overall_trick_performance()
    if (nrow(top_tricks) >= 2) {
      valueBox(
        subtitle = paste0("🥈 2nd Best: ", top_tricks$trick[2]),
        value = paste0(round(top_tricks$mean_lands[2], 2), " lands/session"),
        icon = icon("medal"), color = "aqua"
      )
    } else {
      valueBox("N/A", "2nd Best Trick", icon = icon("medal"), color = "aqua")
    }
  })

  output$top_trick3_vb <- renderValueBox({
    top_tricks <- overall_trick_performance()
    if (nrow(top_tricks) >= 3) {
      valueBox(
        subtitle = paste0("🥉 3rd Best: ", top_tricks$trick[3]),
        value = paste0(round(top_tricks$mean_lands[3], 2), " lands/session"),
        icon = icon("medal"), color = "light-blue"
      )
    } else {
      valueBox(
        "N/A",
        "3rd Best Trick",
        icon = icon("medal"),
        color = "light-blue"
      )
    }
  })

  # --- Radar Chart ---
  output$radar_chart <- renderPlotly({
    perf_data <- overall_trick_performance()
    validate(
      need(
        nrow(perf_data) > 0 &&
          sum(perf_data$mean_lands, na.rm = TRUE) > 0,
        "Not enough data or all mean lands are zero for radar chart."
      )
    )

    # Normalize data (0-1 scale for mean_lands)
    # Handle cases where max is 0 or all values
    # are the same to avoid division by zero or NaN
    max_lands <- max(perf_data$mean_lands, na.rm = TRUE)
    min_lands <- min(perf_data$mean_lands, na.rm = TRUE)

    if (max_lands == min_lands) { # All values are the same
      if (max_lands == 0) { # All are zero
        perf_data$normalized_lands <- 0
      } else { # All are some non-zero constant
        perf_data$normalized_lands <- 1
      }
    } else {
      perf_data$normalized_lands <-
        (perf_data$mean_lands - min_lands) / (max_lands - min_lands)
    }

    # Ensure normalized_lands are not NA if
    # mean_lands was NA (though filter should prevent this)
    perf_data$normalized_lands <-
      ifelse(
        is.na(perf_data$normalized_lands),
        0,
        perf_data$normalized_lands
      )

    plot_ly(
      type = "scatterpolar",
      r = perf_data$normalized_lands,
      theta = perf_data$trick,
      fill = "toself",
      mode = "markers+lines"
    ) |>
      layout(
        polar = list(
          radialaxis = list(
            visible = TRUE,
            range = c(0, 1) # Normalized scale
          )
        ),
        showlegend = FALSE
      )
  })

  # Scatter Plot: Visualizes lands per session over time for a selected trick.
  # Includes a line for the mean number of lands.
  output$scat <- renderPlotly({
    df <- filt()
    validate(need(nrow(df) > 0, "No data"))
    
    # Create a complete date sequence for the selected range
    all_dates <- seq(from = input$rng[1], to = input$rng[2], by = "day")
    complete_df <- tibble(date = all_dates) |>
      left_join(df, by = "date")
    
    # Fill missing values with 0 for the selected trick
    complete_df[[input$trick]] <- replace_na(complete_df[[input$trick]], 0)
    
    mu <- mean(df[[input$trick]], na.rm = TRUE)

    p <- plot_ly(complete_df,
      x = ~date,
      y = as.formula(paste0("~`", input$trick, "`")),
      type = "scatter", mode = "markers+lines",
      # Color points differently for actual data vs filled zeros
      marker = list(
        color = ifelse(is.na(complete_df[[input$trick]]) | 
                      complete_df$date %in% df$date, "blue", "lightblue"),
        size = ifelse(complete_df$date %in% df$date, 8, 4)
      ),
      hovertemplate = paste0(
        "Date: %{x}<br>",
        "Lands: %{y}<br>",
        "<extra></extra>"
      )
    )

    # Add mean line across the full date range
    p <- p |> add_segments(
      x = input$rng[1], xend = input$rng[2],
      y = mu, yend = mu, line = list(dash = "dash", color = "red"),
      inherit = FALSE, showlegend = FALSE,
      name = "Mean"
    )

    p |> layout(
      xaxis = list(
        title = "Date",
        range = c(input$rng[1], input$rng[2]),
        type = "date"
      ),
      yaxis = list(
        title = "Lands",
        rangemode = "tozero"  # Ensure y-axis starts from 0
      ),
      showlegend = FALSE
    )
  })

  # Monthly Heatmap: Shows trick activity aggregated by month.
  # Helps identify trends and consistency in practicing different tricks.
  output$heat <- renderPlotly({
    long <- logs() |>
      select(date, all_of(trick_cols())) |>
      pivot_longer(-date, names_to = "trick", values_to = "lands") |>
      mutate(month = format(floor_date(date, "month"), "%Y-%m"))

    full <- expand_grid(
      month = unique(long$month),
      trick = unique(long$trick)
    ) |>
      left_join(long, by = c("month", "trick")) |>
      mutate(lands = replace_na(lands, 0)) #nolinter

    trick_order <- full |>
      group_by(trick) |> #nolinter
      summarise(total = sum(lands), .groups = "drop") |> #nolinter
      arrange(desc(total)) |> #nolinter
      pull(trick)

    full$trick <- factor(full$trick, levels = rev(trick_order))
    full$month <- factor(full$month, levels = sort(unique(full$month)))

    zmax_val <- if (all(full$lands == 0)) {
      1
    } else {
      quantile(full$lands[full$lands > 0], .95)
    }

    plot_ly(full,
      x = ~month, y = ~trick, z = ~lands,
      type = "heatmap", colorscale = "Viridis",
      text = ~ paste0(
        "Trick: ", trick,
        "<br>Month: ", month,
        "<br>Lands: ", lands
      ),
      hoverinfo = "text", xgap = 1, ygap = 1,
      zmin = 0, zmax = zmax_val
    ) |>
      layout(
        xaxis = list(title = "", tickangle = -45, type = "category"),
        yaxis = list(title = "", type = "category"),
        margin = list(l = 100, b = 50)
      )
  })

  # Raw Log Data Table: Displays the log data in a transposed format.
  # Fields are rows, and sessions are columns for easier viewing of details.
  output$raw <- renderDT({
    df <- logs()
    # transpose: columns → rows
    tdf <- t(df)
    transposed_df <- data.frame(
      Field = rownames(tdf),
      tdf,
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
    datatable(
      transposed_df,
      options = list(pageLength = 10, scrollX = TRUE)
    )
  })

  # Add / Update Row Logic: Handles saving new log entries
  # or updating existing ones.
  # Ensures essential headers (date, location) exist in the Google Sheet.
  # Adds new trick columns with default values if a new trick is logged.
  # Matches entries by date and location to update, otherwise appends a new row.
  observeEvent(input$add, {
    # Read headers as character, keeping line under 80 chars
    hdr <- names(
      read_sheet(
        sheet_url,
        sheet = "Sheet1",
        n_max = 0,
        col_types = "c"
      )
    )

    # ensure essential headers ------------------------------------------------
    if (!"date" %in% hdr) {
      range_write(sheet_url, data.frame(date = "date"),
        sheet = "Sheet1", range = "A1", col_names = FALSE
      )
      hdr <- c("date", hdr)
    }
    if (!"place" %in% hdr && !"location" %in% hdr) {
      col_letter <- LETTERS[length(hdr) + 1]
      range_write(sheet_url, tibble(place = "place"),
        sheet = "Sheet1", range = paste0(col_letter, "1"), col_names = FALSE
      )
      loc_col <- "place"
      hdr <- c(hdr, loc_col)
    } else {
      loc_col <- if ("place" %in% hdr) "place" else "location"
    }
    if (!"date_clean" %in% hdr) hdr <- c(hdr, "date_clean")

    # add new trick header AND fill body with 0s
    new_trick_added <- FALSE # Flag to check if a new trick was added
    if (!(input$new_trick %in% hdr)) {
      # 1. Get current data to know the number of rows
      current_data <- read_sheet(
        sheet_url,
        sheet = "Sheet1",
        range = "A:A",
        col_types = "c",
        col_names = FALSE
      )
      num_data_rows <- nrow(current_data) - 1 # Subtract header row

      # 2. Determine the next available column letter/index
      new_col_idx <- length(hdr) + 1
      if (new_col_idx <= 26) {
        col_letter <- LETTERS[new_col_idx]
      } else {
        first_letter_idx <- floor((new_col_idx - 1) / 26)
        second_letter_idx <- (new_col_idx - 1) %% 26 + 1
        col_letter <- paste0(
          LETTERS[first_letter_idx],
          LETTERS[second_letter_idx]
        )
      }

      # 3. Write the new header
      tryCatch(
        {
          range_write(
            sheet_url,
            tibble(!!input$new_trick := input$new_trick),
            sheet = "Sheet1",
            range = paste0(col_letter, "1"),
            col_names = FALSE
          )
          hdr <- c(hdr, input$new_trick)
          new_trick_added <- TRUE

          # 4. Write default values (NA) for existing rows in the new column
          if (num_data_rows > 0) {
            default_values <- tibble(
              !!input$new_trick := rep(NA_real_, num_data_rows)
            )
            range_write(
              sheet_url,
              default_values,
              sheet = "Sheet1",
              range = paste0(col_letter, "2"), # start at row 2
              col_names = FALSE
            )
          }

          gc()
          Sys.sleep(0.5)
          logs_trigger(Sys.time())
        },
        error = function(e) {
          output$add_msg <- renderText(paste("Error adding header:", e$message))
        }
      )
    }

    # Use read_logs() for normalized data processing
    df <- read_logs()
    date_col <- if ("date" %in% names(df)) "date" else "date_clean"

    row_match <- which(
      as.character(df[[date_col]]) == as.character(input$new_date) &
        replace_na(df[[loc_col]], "") == input$new_loc
    )

    row_list <- if (length(row_match) == 1) {
      current_row_data <- df[row_match, , drop = FALSE]
      temp_list <- setNames(as.list(rep(NA_character_, length(hdr))), hdr)
      for (col in intersect(names(current_row_data), hdr)) {
        temp_list[[col]] <- current_row_data[[col]][1]
      }
      temp_list
    } else {
      setNames(as.list(rep(NA_character_, length(hdr))), hdr)
    }

    row_list[["date"]] <- as.character(input$new_date)
    row_list[["date_clean"]] <- as.character(input$new_date)
    row_list[[loc_col]] <- input$new_loc
    row_list[[input$new_trick]] <- as.character(input$new_land)

    final_row_list <- row_list
    # Use is_numeric_like() for robust trick column detection
    current_trick_cols <- setdiff(
      names(df)[sapply(df, is_numeric_like)],
      c(
        "date", "date_clean", loc_col, grep("^attempts_", hdr, value = TRUE),
        "randomized", "weights", "C.virus", "board"
      )
    )
    for (col in current_trick_cols) {
      if (is.na(final_row_list[[col]]) && col != input$new_trick) {
        final_row_list[[col]] <- 0  # numeric zero, not "0"
      }
    }

    new_row <- as_tibble(final_row_list)[, hdr]

    tryCatch(
      {
        if (length(row_match) == 1) {
          rng <- cell_limits(c(row_match + 1, 1), c(row_match + 1, length(hdr)))
          range_write(sheet_url, new_row,
            sheet = "Sheet1",
            range = rng, col_names = FALSE, reformat = FALSE
          )
          output$add_msg <- renderText("🔄 Row updated")
        } else {
          for (col in current_trick_cols) {
            new_row[[col]] <- replace_na(new_row[[col]], "0")
          }
          sheet_append(sheet_url, new_row, sheet = "Sheet1")
          output$add_msg <- renderText("✅ Row added")
        }
        if (!new_trick_added) {
          logs_trigger(Sys.time())
        }
      },
      error = function(e) {
        output$add_msg <- renderText(paste("Error:", e$message))
      }
    )
  })

  # Randomiser Logic: Generates a random list of tricks for practice.
  # Number of tricks is determined by a slider input.
  output$nrand_ui <- renderUI(
    sliderInput("nrand", "How many tricks?", 1, max(1, length(trick_cols())),
      value = min(5, max(1, length(trick_cols()))), step = 1
    )
  )
  plan <- eventReactive(input$roll, {
    slice_sample(tibble(trick = trick_cols()), n = input$nrand)
  })
  output$plan <- renderDT(datatable(plan(),
    rownames = FALSE,
    options = list(dom = "tip", pageLength = 10)
  ))

  # Calendar Heatmap: Visualizes daily skate activity over a selected year.
  # Allows navigation to previous/next years.
  # Highlights the current day.
  cal_year <- reactiveVal(year(Sys.Date())) # Initialize with current year.
  observeEvent(input$prev_year, cal_year(cal_year() - 1)) # Navigate back.
  observeEvent(input$next_year, cal_year(cal_year() + 1)) # Navigate forward.
  output$cal_year_lbl <- renderUI(strong(cal_year())) # Display selected year.

  output$calendar <- renderPlotly({
    yr <- cal_year()
    df <- logs() |>
      mutate(
        day = as.Date(date),
        y = wday(day, week_start = 1),
        wk = isoweek(day)
      ) |>
      filter(year(day) == yr)

    # Force all trick columns to numeric (except date, y, wk)
    trick_cols_now <- setdiff(names(df), c("day", "date", "y", "wk"))
    df[trick_cols_now] <-
      lapply(
        df[trick_cols_now],
        function(x) suppressWarnings(as.numeric(x))
      )

    df <- df |>
      group_by(day, y, wk) |> #nolinter
      summarise(
        lands = sum(across(all_of(trick_cols_now)), na.rm = TRUE),
        .groups = "drop"
      )

    grid <- tibble(day = seq.Date(as.Date(sprintf("%s-01-01", yr)),
      as.Date(sprintf("%s-12-31", yr)),
      by = "day"
    )) |>
      mutate(
        y = wday(day, week_start = 1),
        wk = isoweek(day)
      ) |>
      left_join(df, by = c("day", "y", "wk")) |>
      mutate(
        lands = replace_na(lands, 0), #nolinter
        is_today = day == Sys.Date(),
        y_plot = -y #nolinter
      )

    zmax <- if (all(grid$lands == 0)) {
      1
    } else {
      quantile(grid$lands[grid$lands > 0], .95)
    }

    # Data for month annotations
    month_centers_dates <- seq.Date(
      as.Date(sprintf("%s-01-15", yr)),
      by = "month",
      length.out = 12
    )
    month_centers_dates <- month_centers_dates[year(month_centers_dates) == yr]

    month_annotations_data <- tibble(
      month_day = month_centers_dates
    ) |>
      mutate(
        wk = isoweek(month_day), #nolinter
        month_label = month(month_day, label = TRUE, abbr = TRUE)
      )

    annotations_list <- lapply(seq_len(nrow(month_annotations_data)), function(i) { #nolinter
      list(
        x = month_annotations_data$wk[i],
        y = 1.06,
        text = month_annotations_data$month_label[i],
        showarrow = FALSE,
        font = list(color = "white", size = 10),
        xanchor = "center",
        yanchor = "bottom",
        xref = "x",
        yref = "paper"
      )
    })

    p <- plot_ly(grid,
      x = ~wk, y = ~y_plot, z = ~lands,
      type = "heatmap", showscale = FALSE,
      colorscale = "Cividis", # Changed colorscale to Cividis
      zmin = 0, zmax = zmax,
      hoverinfo = "text",
      text = ~ paste0(day, "<br>Lands: ", lands),
      xgap = 1, ygap = 1 # Keep existing gaps
    ) |>
      layout(
        annotations = annotations_list,
        yaxis = list(
          tickmode = "array",
          tickvals = -1:-7,
          ticktext = c("M", "T", "W", "T", "F", "S", "S"),
          zeroline = FALSE, title = "",
          tickfont = list(color = "white"),
          titlefont = list(color = "white")
        ),
        xaxis = list(
          title = "", showgrid = FALSE, zeroline = FALSE,
          tickfont = list(color = "white"),
          titlefont = list(color = "white")
        ),
        margin = list(l = 20, r = 10, t = 30, b = 10),
        paper_bgcolor = "#343a40", plot_bgcolor = "#343a40"
      )

    if (any(grid$is_today)) {
      p <- add_markers(p,
        data = grid |> filter(is_today), #nolinter
        x = ~wk, y = ~y_plot,
        marker = list(
          size = 14, color = "rgba(0,0,0,0)",
          line = list(color = "white", width = 2)
        ),
        hoverinfo = "skip", inherit = FALSE
      )
    }
    p
  })

  # Debugging Info: Displays latest date and row count from data
  output$debug_info <- renderText({
    df <- logs()
    latest_date <- max(df$date, na.rm = TRUE)
    nrows <- nrow(df)
    paste("Latest date in data:", latest_date, "| Total rows:", nrows)
  })

  observe({
    df <- logs()
    req(nrow(df)>0)
    latest <- max(df$date, na.rm=TRUE)
    earliest <- latest - 30
    updateDateRangeInput(session, "rng",
      start = earliest,
      end   = latest
    )
  })
}

# ── Launch Application ───────────────────────────────────────────────────────
# Runs the Shiny application using the defined UI and server logic.
shinyApp(ui, server)
# ───────────────────────────────────────────────────────────────────────────
