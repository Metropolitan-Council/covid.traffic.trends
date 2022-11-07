#' map_inputs UI Function
#'
#' @description A shiny Module.
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @noRd
#' @importFrom shinyWidgets pickerInput pickerOptions
#' @importFrom shiny NS tagList
mod_user_inputs_ui <- function(id, type = "map_daily") {
  ns <- NS(id)


  if (type == "map_daily") {
    tagList(
      dateInput(ns("select_date"), "Select a date to see change in the map over time",
        value = max(covid.traffic.trends::predicted_actual_by_region$date),
        min = min(covid.traffic.trends::predicted_actual_by_region$date),
        max = max(covid.traffic.trends::predicted_actual_by_region$date),
        format = "mm/dd/yyyy",
        startview = "month"
      ),
      shinyWidgets::pickerInput(ns("select_corridor"),
        "Select a corridor",
        choices = covid.traffic.trends::unique_corridors,
        selected = covid.traffic.trends::unique_corridors,
        multiple = TRUE,
        options = shinyWidgets::pickerOptions(
          actionsBox = TRUE,
          dropupAuto = FALSE,
          liveSearch = TRUE
        )
      )
    )
  } else if (type == "plot_corridor_hour") {
    tagList(
      selectInput(ns("select_corridor_month_year"),
        "Select a month",
        choices = unique(covid.traffic.trends::predicted_actual_corridor_hour$user_month_year) %>%
          sort(),
        selected = max(covid.traffic.trends::predicted_actual_corridor_hour$user_month_year)
      ),
      shinyWidgets::pickerInput(
        ns("select_corridor"),
        "Select a corridor",
        choices = unique(covid.traffic.trends::predicted_actual_corridor_hour$corridor_route),
        selected = "I-35W",
        multiple = FALSE,
        options = shinyWidgets::pickerOptions(
          actionsBox = TRUE,
          dropupAuto = FALSE,
          liveSearch = TRUE
        )
      )
    )
  } else if (type == "map_station_trends") {
    tagList(
      selectInput(ns("select_station_month_year"),
        "Select a month",
        choices = unique(covid.traffic.trends::predicted_actual_node_day_part$Freeway_Segment$user_month_year) %>%
          sort(),
        selected = max(covid.traffic.trends::predicted_actual_corridor_hour$user_month_year)
      ),
      selectInput(
        ns("select_station_day_part"),
        "Select a day part",
        choices = unique(covid.traffic.trends::predicted_actual_node_day_part$Freeway_Segment$day_part),
        selected = "Morning, 7-9AM",
        multiple = FALSE
      ),
      shinyWidgets::pickerInput(ns("select_station_corridor"),
        "Select a corridor",
        choices = covid.traffic.trends::unique_corridors,
        selected = covid.traffic.trends::unique_corridors,
        multiple = TRUE,
        options = shinyWidgets::pickerOptions(
          actionsBox = TRUE,
          dropupAuto = FALSE,
          liveSearch = TRUE
        )
      )
    )
  }
}

#' map_inputs Server Function
#'
#' @noRd
mod_user_inputs_server <- function(input, output, session) {
  ns <- session$ns
  vals <- reactiveValues()

  observeEvent(input$select_date, {
    vals$date <- input$select_date
  })

  # hourly by corridor -----

  observeEvent(input$select_corridor_month_year, {
    vals$month_year <- input$select_corridor_month_year
    vals$current_corrs <- current_corrs()
  })


  observeEvent(input$select_corridor, {
    vals$corridor_route <- input$select_corridor
    vals$current_corrs <- current_corrs()
  })

  current_corrs <- reactive({
    req(input$select_corridor)
    req(input$select_corridor_month_year)
    display_data <- covid.traffic.trends::predicted_actual_corridor_hour[user_month_year == input$select_corridor_month_year & corridor_route == input$select_corridor]

    return(display_data)
  })

  # day part node map -----

  observeEvent(input$select_station_month_year, {
    vals$select_station_month_year <- input$select_station_month_year
  })

  observeEvent(input$select_station_day_part, {
    vals$select_station_day_part <- input$select_station_day_part
  })

  observeEvent(input$select_station_corridor, {
    vals$select_station_corridor <- input$select_station_corridor
  })

  return(vals)
}

## To be copied in the UI
# mod_map_inputs_ui("map_inputs_ui_1")

## To be copied in the server
# callModule(mod_map_inputs_server, "map_inputs_ui_1")
