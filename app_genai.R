###############################################################################
# app.R  –  Skate‑trick dashboard  (v12‑full: auto‑add headers + full plots)
# how to run shiny::runApp("/yourpath/app_genai.R")
###############################################################################
library(shiny)
library(shinydashboard)
library(googlesheets4)
library(dplyr)
library(tidyr)
library(plotly)
library(lubridate)
library(DT)
library(rlang)
library(tidychatmodels)

# ── Google‑Sheets authentication --------------------------------------------
if (nzchar(Sys.getenv("GS4_SA_JSON"))) {
  gs4_auth(path = Sys.getenv("GS4_SA_JSON")) # on shinyapps.io
} else {
  gs4_auth(email = TRUE, cache = ".secrets") # local OAuth
}

# ── OpenAI API Key loading and checking -------------------------------------
# For local development, try to load from .Renviron if not already set
if (Sys.getenv("OPENAI_API_KEY") == "" && file.exists(".Renviron")) {
  readRenviron(".Renviron")
}

# Check if OPENAI_API_KEY is set
OPENAI_API_KEY <- Sys.getenv("OPENAI_API_KEY") # nolint
if (OPENAI_API_KEY == "") {
  if (nzchar(Sys.getenv("GS4_SA_JSON"))) { # Running on shinyapps.io
    message("OPENAI_API_KEY not set as an environment variable on shinyapps.io. Please set it in the application settings.")
  } else { # Running locally
    message("OPENAI_API_KEY not found. Please create a .Renviron file in the project root (e.g., /home/stormbird/sk8bro/.Renviron) and add the line: OPENAI_API_KEY='your_api_key_here'")
  }
} else {
  message("OPENAI_API_KEY loaded successfully.")
}

SHEET <- Sys.getenv("SHEET_ID") # Google Sheet ID

# ── helpers ------------------------------------------------------------------
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
read_logs <- function() {
  # Read the sheet with explicit detection of column types
  df <- read_sheet(SHEET, sheet = "Sheet1", .name_repair = "unique")

  # Handle date column
  if ("date" %in% names(df)) {
    df$date <- safe_date(df$date)
  } else if ("date_clean" %in% names(df)) {
    df <- rename(df, date = date_clean)
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
    # Skip conversion for columns that are already numeric, dates, or lists
    if (is.numeric(df[[col]]) || inherits(df[[col]], "Date") || inherits(df[[col]], "POSIXt")) {
      next
    }

    # Check if the column is a list type (which can't be directly converted to numeric)
    if (is.list(df[[col]])) {
      # If it's a list column, we can't directly convert to numeric
      # Just leave it as is - it will be filtered out by trick_cols()
      next
    }

    # For character columns, try safe numeric conversion
    tryCatch(
      {
        df[[col]] <- suppressWarnings(as.numeric(df[[col]]))
      },
      error = function(e) {
        # If conversion fails, leave the column as is
        warning(paste("Could not convert column", col, "to numeric:", e$message))
      }
    )
  }

  df
}

# ── UI -----------------------------------------------------------------------
ui <- dashboardPage(
  skin = "blue",
  dashboardHeader(title = "Skate‑trick tracker"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Dashboard", tabName = "dash", icon = icon("chart-line")),
      menuItem("Log", tabName = "log", icon = icon("pen")),
      menuItem("Randomiser", tabName = "rand", icon = icon("dice")),
      menuItem("Chat", tabName = "chat", icon = icon("comments")),
      menuItem("Coaching", tabName = "coach", icon = icon("user-graduate"))
    )
  ),
  dashboardBody(
    tabItems(
      # ------- dashboard tab -------------------------------------------------
      tabItem(
        "dash",
        fluidRow(
          box(
            width = 3, status = "info", solidHeader = TRUE, title = "Inputs",
            selectInput("trick", "Trick", choices = NULL),
            dateRangeInput("rng", "Dates", Sys.Date() - 30, Sys.Date())
          ),
          valueBoxOutput("sess"), valueBoxOutput("tot"), valueBoxOutput("mean")
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
          title = tagList(
            "Year calendar",
            actionButton("prev_year", NULL, icon("chevron-left"), class = "btn-xs"),
            uiOutput("cal_year_lbl"),
            actionButton("next_year", NULL, icon("chevron-right"), class = "btn-xs")
          ),
          plotlyOutput("calendar", height = 160)
        )),
        fluidRow(box(
          width = 12, status = "warning", solidHeader = TRUE,
          title = "Raw log data", DTOutput("raw")
        ))
      ),

      # ------- logging tab ---------------------------------------------------
      tabItem(
        "log",
        box(
          width = 4, status = "success", solidHeader = TRUE, title = "Log new session",
          dateInput("new_date", "Date", Sys.Date()),
          uiOutput("new_loc_ui"),
          uiOutput("new_trick_ui"),
          numericInput("new_land", "Landed", 0, min = 0),
          actionButton("add", "Save / update row", class = "btn-success"),
          verbatimTextOutput("add_msg")
        )
      ),

      # ------- randomiser tab ------------------------------------------------
      tabItem(
        "rand",
        box(
          width = 4, status = "info", solidHeader = TRUE, title = "Shuffle practice list",
          uiOutput("nrand_ui"),
          actionButton("roll", "Shuffle!", icon = icon("dice")),
          DTOutput("plan")
        )
      ),

      # ------- chat tab ------------------------------------------------------
      tabItem(
        "chat",
        fluidRow(
          box(
            width = 12, status = "primary", solidHeader = TRUE, title = "Chat with Sheet1 data",
            verbatimTextOutput("chat_history"),
            textInput("chat_input", "Your question:", ""),
            actionButton("chat_send", "Send", icon = icon("paper-plane"))
          )
        )
      ),

      # ------- coaching tab --------------------------------------------------
      tabItem(
        "coach",
        fluidRow(
          box(
            width = 12, status = "info", solidHeader = TRUE, title = "Skate Trick Coach",
            verbatimTextOutput("coach_chat_history"),
            textInput("coach_chat_input", "Ask your coach:", ""),
            actionButton("coach_chat_send", "Send", icon = icon("paper-plane"))
          )
        )
      )
    )
  )
)

# ── SERVER -------------------------------------------------------------------
server <- function(input, output, session) {
  # trigger: re‑read sheet when updated --------------------------------------
  logs_trigger <- reactiveVal(Sys.time())
  logs <- reactive({
    logs_trigger()
    read_logs()
  })

  # which numeric columns are real tricks ------------------------------------
  trick_cols <- reactive({
    raw <- logs()

    # Identify columns that are numeric or can be treated as numeric
    potential_trick_cols <- names(raw)[sapply(raw, function(x) {
      # Skip list columns
      if (is.list(x)) {
        return(FALSE)
      }
      # Keep already numeric columns
      if (is.numeric(x)) {
        return(TRUE)
      }
      # Check if character columns can be coerced (even if all are NA/0)
      if (is.character(x)) {
        # Check if *any* non-NA value can be coerced, or if it's all NA/empty
        vals <- na.omit(x[x != ""])
        if (length(vals) == 0) {
          return(TRUE)
        } # Keep if all NA/empty initially
        return(all(suppressWarnings(!is.na(as.numeric(vals)))))
      }
      return(FALSE) # Skip other types
    })]

    # Exclude known non-trick columns
    setdiff(
      potential_trick_cols,
      c(
        "date", "date_clean", "place", "location", # Ensure these are excluded
        grep("^attempts_", names(raw), value = TRUE),
        "randomized", "weights", "C.virus", "board"
      )
    )
  })

  # dropdowns -----------------------------------------------------------------
  observe({
    tr <- trick_cols()
    updateSelectInput(session, "trick",
      choices = tr,
      selected = input$trick %||% tr[1]
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

  # KPIs ----------------------------------------------------------------------
  filt <- reactive({
    req(input$trick, input$rng)
    logs() |> filter(date >= input$rng[1], date <= input$rng[2])
  })
  output$sess <- renderValueBox(valueBox(nrow(filt()), "Sessions", icon("calendar")))
  output$tot <- renderValueBox(valueBox(
    sum(filt()[[input$trick]], na.rm = TRUE),
    "Total lands", icon("check")
  ))
  output$mean <- renderValueBox(valueBox(
    round(mean(filt()[[input$trick]], na.rm = TRUE), 2),
    "Mean / session", icon("minus")
  ))

  # scatter -------------------------------------------------------------------
  output$scat <- renderPlotly({
    df <- filt()

    # Validate data frame and selected trick
    shiny::validate(
      need(is.data.frame(df) && nrow(df) > 0, "No data available for the selected filters. Please adjust date range or trick selection."),
      need(input$trick %in% names(df), paste("Selected trick '", input$trick, "' not found in the data for the current filters.", sep=""))
    )

    trick_values <- df[[input$trick]]
    mu <- if(all(is.na(trick_values))) NA_real_ else mean(trick_values, na.rm = TRUE)

    # Create tooltip text using sprintf for robustness and explicit NA handling
    df$tooltip_text <- sprintf(
      "Date: %s<br>Trick: %s<br>Lands: %s",
      format(df$date, "%Y-%m-%d"), # Explicitly format date
      as.character(input$trick), # Ensure input$trick is treated as character
      ifelse(is.na(trick_values), "N/A", as.character(trick_values))
    )

    p <- ggplot(df, aes(x = date, y = .data[[input$trick]])) +
      geom_line(aes(text = tooltip_text), alpha = 0.7) +
      geom_point(aes(text = tooltip_text), alpha = 0.7) +
      labs(y = "Lands", x = "Date", title = NULL) + # Title removed as box provides it
      theme_minimal()

    # Add mean line only if mu is a valid number
    if (!is.na(mu)) {
      p <- p + geom_hline(
        aes(yintercept = mu, text = sprintf("Mean: %.2f", mu)), # Add text aesthetic for hline tooltip
        linetype = "dashed", color = "red"
      )
    }

    ggplotly(p, tooltip = "text")
  })

  # monthly heat‑map ----------------------------------------------------------
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
      mutate(lands = replace_na(lands, 0))

    trick_order <- full |>
      group_by(trick) |>
      summarise(total = sum(lands), .groups = "drop") |>
      arrange(desc(total)) |>
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

  # raw log data (transposed) ------------------------------------------------
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

  # ---- add / update row -----------------------------------------------------
  observeEvent(input$add, {
    hdr <- names(read_sheet(SHEET, sheet = "Sheet1", n_max = 0, col_types = "c")) # Read headers as char

    # ensure essential headers ------------------------------------------------
    if (!"date" %in% hdr) {
      range_write(SHEET, data.frame(date = "date"),
        sheet = "Sheet1", range = "A1", col_names = FALSE
      )
      hdr <- c("date", hdr)
    }
    if (!"place" %in% hdr && !"location" %in% hdr) {
      col_letter <- LETTERS[length(hdr) + 1]
      range_write(SHEET, tibble(place = "place"),
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
      current_data <- read_sheet(SHEET, sheet = "Sheet1", range = "A:A", col_types = "c", col_names = FALSE)
      num_data_rows <- nrow(current_data) - 1 # Subtract header row

      # 2. Determine the next available column letter/index
      new_col_idx <- length(hdr) + 1
      if (new_col_idx <= 26) {
        col_letter <- LETTERS[new_col_idx]
      } else {
        first_letter_idx <- floor((new_col_idx - 1) / 26)
        second_letter_idx <- (new_col_idx - 1) %% 26 + 1
        col_letter <- paste0(LETTERS[first_letter_idx], LETTERS[second_letter_idx])
      }

      # 3. Write the new header
      tryCatch(
        {
          range_write(
            SHEET,
            tibble(!!input$new_trick := input$new_trick),
            sheet = "Sheet1",
            range = paste0(col_letter, "1"),
            col_names = FALSE
          )
          hdr <- c(hdr, input$new_trick)
          new_trick_added <- TRUE

          # 4. Write default values (NA) for existing rows in the new column
          if (num_data_rows > 0) {
            default_values <- tibble(!!input$new_trick := rep(NA_real_, num_data_rows))
            range_write(
              SHEET,
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
          return()
        }
      )
    }

    df <- read_sheet(SHEET, sheet = "Sheet1", col_types = "c")
    date_col <- if ("date" %in% names(df)) "date" else "date_clean"
    df[[date_col]] <- safe_date(df[[date_col]])

    row_match <- which(as.character(df[[date_col]]) == as.character(input$new_date) &
      replace_na(df[[loc_col]], "") == input$new_loc)

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
    current_trick_cols <- setdiff(
      hdr[sapply(df, function(x) is.numeric(safe_date(x)) || is.numeric(x))],
      c(
        "date", "date_clean", loc_col, grep("^attempts_", hdr, value = TRUE),
        "randomized", "weights", "C.virus", "board"
      )
    )
    for (col in current_trick_cols) {
      if (is.na(final_row_list[[col]]) && col != input$new_trick) {
        final_row_list[[col]] <- "0"
      }
    }

    new_row <- as_tibble(final_row_list)[, hdr]

    tryCatch(
      {
        if (length(row_match) == 1) {
          rng <- cell_limits(c(row_match + 1, 1), c(row_match + 1, length(hdr)))
          range_write(SHEET, new_row,
            sheet = "Sheet1",
            range = rng, col_names = FALSE, reformat = FALSE
          )
          output$add_msg <- renderText("🔄 Row updated")
        } else {
          for (col in current_trick_cols) {
            new_row[[col]] <- replace_na(new_row[[col]], "0")
          }
          sheet_append(SHEET, new_row, sheet = "Sheet1")
          output$add_msg <- renderText("✅ Row added")
        }
        if (!new_trick_added) {
          logs_trigger(Sys.time())
        }
      },
      error = function(e) output$add_msg <- renderText(paste("Error:", e$message))
    )
  })

  # randomiser ---------------------------------------------------------------
  output$nrand_ui <- renderUI(
    sliderInput("nrand", "How many tricks?", 1, length(trick_cols()),
      value = min(5, length(trick_cols())), step = 1
    )
  )
  plan <- eventReactive(input$roll, {
    slice_sample(tibble(trick = trick_cols()), n = input$nrand)
  })
  output$plan <- renderDT(datatable(plan(),
    rownames = FALSE,
    options = list(dom = "tip", pageLength = 10)
  ))

  # calendar heat‑map --------------------------------------------------------
  cal_year <- reactiveVal(year(Sys.Date()))
  observeEvent(input$prev_year, cal_year(cal_year() - 1))
  observeEvent(input$next_year, cal_year(cal_year() + 1))
  output$cal_year_lbl <- renderUI(strong(cal_year()))

  output$calendar <- renderPlotly({
    yr <- cal_year()
    df <- logs() |>
      mutate(
        day = as.Date(date),
        y = wday(day, week_start = 1),
        wk = isoweek(day)
      ) |>
      filter(year(day) == yr) |>
      group_by(day, y, wk) |>
      summarise(lands = sum(across(where(is.numeric))), .groups = "drop")

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
        lands = replace_na(lands, 0),
        is_today = day == Sys.Date(),
        y_plot = -y
      )

    zmax <- if (all(grid$lands == 0)) {
      1
    } else {
      quantile(grid$lands[grid$lands > 0], .95)
    }

    # Data for month annotations
    month_centers_dates <- seq.Date(as.Date(sprintf("%s-01-15", yr)), by = "month", length.out = 12)
    month_centers_dates <- month_centers_dates[year(month_centers_dates) == yr]

    month_annotations_data <- tibble(
      month_day = month_centers_dates
    ) |>
      mutate(
        wk = isoweek(month_day),
        month_label = month(month_day, label = TRUE, abbr = TRUE)
      )

    annotations_list <- lapply(1:nrow(month_annotations_data), function(i) {
      list(
        x = month_annotations_data$wk[i],
        y = 1.06, # Positioned above the plot
        text = month_annotations_data$month_label[i],
        showarrow = FALSE,
        font = list(color = "white", size = 10),
        xanchor = 'center',
        yanchor = 'bottom',
        xref = 'x', # x coordinate refers to data (week number)
        yref = 'paper' # y coordinate refers to paper (fraction of plot height)
      )
    })

    p <- plot_ly(grid,
      x = ~wk, y = ~y_plot, z = ~lands,
      type = "heatmap", showscale = FALSE,
      colorscale = "Cividis", # Changed colorscale to Cividis
      zmin = 0, zmax = zmax,
      hoverinfo = "text",
      text = ~ paste0(day, "<br>Lands: ", lands),
      xgap = 1, ygap = 1 # Gaps for cell separation
    ) |>
      layout(
        annotations = annotations_list, # Add month annotations
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
        margin = list(l = 20, r = 10, t = 30, b = 10), # Increased top margin for annotations
        paper_bgcolor = "#343a40", plot_bgcolor = "#343a40"
      )

    if (any(grid$is_today)) {
      p <- add_markers(p,
        data = grid |> filter(is_today),
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

  # chat logic ---------------------------------------------------------------
  chat_history <- reactiveVal(data.frame(role = character(), content = character(), stringsAsFactors = FALSE))

  observeEvent(input$chat_send, {
    req(input$chat_input)

    # Add user message to history
    new_entry <- data.frame(role = "User", content = input$chat_input, stringsAsFactors = FALSE)
    chat_history(rbind(chat_history(), new_entry))
    updateTextInput(session, "chat_input", value = "")

    # Check for API key
    api_key <- Sys.getenv("OPENAI_API_KEY")
    if (api_key == "") {
      new_entry <- data.frame(role = "System", content = "OPENAI_API_KEY not set. Please ensure the API key is available in the environment.", stringsAsFactors = FALSE)
      chat_history(rbind(chat_history(), new_entry))
      return()
    }

    # Prepare data context
    skating_data <- logs()
    data_context <- paste(
      "The following is recent data from the user's skateboarding trick log:",
      paste(capture.output(print(head(skating_data, 25))), collapse = "\n"),
      "Each numeric column represents a specific trick and how many times they landed it per session.",
      sep = "\n"
    )

    system_message <- paste(
      "You are an assistant specializing in analyzing skateboarding progression data. Your task is to provide detailed insights about a skateboarder's trick development based on their tracking data. You should identify patterns, progression trends, and areas of strength or improvement.",
      "Below is the skateboarding trick data to analyze:",
      "<trick_data>",
      data_context,
      "</trick_data>",
      "Please analyze this data thoroughly and provide specific, data-driven insights. Your analysis should:",
      "1. Identify trends in trick progression (improvement over time, plateaus, breakthroughs)",
      "2. Calculate and highlight success rates for different tricks",
      "3. Note any correlation between practice frequency and success rate",
      "4. Identify the skater's strongest and most challenging tricks",
      "5. Suggest areas where the skater is showing the most improvement",
      "6. Point out any patterns in learning certain types of tricks (flip tricks vs. grinds, etc.)",
      "Present your analysis in a clear, organized manner using concrete numbers and percentages whenever possible. For example, instead of saying \"you're getting better at kickflips,\" say \"your kickflip success rate improved from 30% in March to 65% in May, a 117% improvement.\"",
      "Format your response as follows:",
      "<analysis>",
      "Begin with a high-level summary of the skater's overall progression.",
      "Then provide specific sections covering:",
      "- Trick success rates and improvement",
      "- Practice patterns and their correlation to success",
      "- Strengths and areas for improvement",
      "- Notable milestones or breakthroughs",
      "- Comparative analysis between different trick types or time periods",
      "End with key insights about the skater's progression journey.",
      "</analysis>",
      "Remember to:",
      "- Use concrete numbers and percentages",
      "- Refer to specific dates or time periods",
      "- Compare progress across different time frames",
      "- Identify both positive trends and potential improvement areas",
      "- Base all insights directly on the data provided"
    )

    # Create chat and send to OpenAI
    chat <- create_chat("openai", api_key = api_key) |>
      # gpt-4.1-nano for faster response and gpt-4o-mini-search-preview for reference
      add_model("gpt-4o-mini-search-preview") |>
      add_message(role = "system", message = system_message) |>
      add_message(role = "user", message = input$chat_input)

    # Process response
    response_chat <- tryCatch(
      {
        chat |> perform_chat()
      },
      error = function(e) {
        error_message <- if (grepl("401", e$message)) {
          "Unauthorized: Please verify that your OPENAI_API_KEY is valid and has the correct permissions."
        } else {
          paste("Error communicating with OpenAI:", e$message)
        }
        new_entry <- data.frame(role = "System", content = error_message, stringsAsFactors = FALSE)
        chat_history(rbind(chat_history(), new_entry))
        return(NULL)
      }
    )

    if (!is.null(response_chat)) {
      assistant_response <- response_chat |> extract_chat(silent = TRUE)
      assistant_message <- tail(assistant_response$message, 1)

      # Add assistant response to chat history
      new_entry <- data.frame(role = "Assistant", content = assistant_message, stringsAsFactors = FALSE)
      chat_history(rbind(chat_history(), new_entry))
    }
  })

  output$chat_history <- renderPrint({
    hist <- chat_history()
    for (i in seq_len(nrow(hist))) {
      cat(sprintf("[%s] %s\n\n", hist$role[i], hist$content[i]))
    }
  })

  # coaching chat logic -------------------------------------------------------
  coach_chat_log <- reactiveVal(data.frame(role = character(), content = character(), stringsAsFactors = FALSE))

  observeEvent(input$coach_chat_send, {
    req(input$coach_chat_input)

    api_key <- Sys.getenv("OPENAI_API_KEY")
    if (api_key == "") {
      new_log_entries <- rbind(
        coach_chat_log(),
        data.frame(role = "System", content = "OPENAI_API_KEY not set. Please ensure the API key is available in the environment.", stringsAsFactors = FALSE)
      )
      coach_chat_log(new_log_entries)
      return()
    }

    current_tricks_summary <- logs()

    trick_data_context <- paste(
      "Here's a summary of the user's recent trick activity:",
      paste(capture.output(print(head(current_tricks_summary, 10))), collapse = "\n"),
      "The user is looking for coaching advice on their skate tricks.",
      sep = "\n"
    )

    system_message_coaching <- paste(
      "You are a friendly and encouraging skateboarding coach. ",
      "Your goal is to help the user improve their skate tricks. ",
      "Ask clarifying questions if needed. Provide specific, actionable, and positive advice on how they can improve. Reference and consider their logged skateboarding tricks and activity if provided. Use supportive, enthusiastic language that motivates and reassures the user. ",
      "Always begin by reviewing or reasoning through the user's logged activity, current trick level, or any details they share before offering advice or concluding directions. Do not give conclusions, advice, or summary before exploring the context or asking clarifying questions if necessary. ",
      "Maintain the format provided by the user, preserving any structure or organization present in their input. ",
      "# Output Format ",
      "Respond in a short, encouraging paragraph using friendly and supportive language. Always reference provided trick logs or activity first before offering feedback or suggestions. If logged tricks are not provided, ask clarifying questions before making recommendations. ",
      "Here's some context on their activity: ",
      trick_data_context
    )

    # Create a new chat object each time instead of clearing messages
    current_chat <- create_chat("openai", api_key = api_key) |>
      add_model("gpt-4o") |>
      add_message(role = "system", message = system_message_coaching) |>
      add_message(role = "user", message = input$coach_chat_input)

    response_chat <- tryCatch(
      {
        current_chat |> perform_chat()
      },
      error = function(e) {
        error_message <- if (grepl("401", e$message)) {
          "Unauthorized: Please verify that your OPENAI_API_KEY is valid and has the correct permissions."
        } else {
          paste("Error communicating with OpenAI:", e$message)
        }
        new_log_entries <- rbind(
          coach_chat_log(),
          data.frame(role = "You", content = input$coach_chat_input, stringsAsFactors = FALSE),
          data.frame(role = "System", content = error_message, stringsAsFactors = FALSE)
        )
        coach_chat_log(new_log_entries)
        updateTextInput(session, "coach_chat_input", value = "") # Clear input even on error
        return(NULL)
      }
    )

    if (is.null(response_chat)) {
      return()
    }

    assistant_response <- response_chat |> extract_chat(silent = TRUE)
    assistant_message <- tail(assistant_response$message, 1)

    new_log_entries <- rbind(
      coach_chat_log(),
      data.frame(role = "You", content = input$coach_chat_input, stringsAsFactors = FALSE),
      data.frame(role = "Coach", content = assistant_message, stringsAsFactors = FALSE)
    )
    coach_chat_log(new_log_entries)

    updateTextInput(session, "coach_chat_input", value = "")
  })

  output$coach_chat_history <- renderPrint({
    log <- coach_chat_log()
    if (nrow(log) > 0) {
      for (i in seq_len(nrow(log))) {
        cat(sprintf("%s: %s\n\n", log$role[i], log$content[i]))
      }
    } else {
      cat("Ask your coach a question to get started!")
    }
  })
}

shinyApp(ui, server)
# ───────────────────────────────────────────────────────────────────────────
