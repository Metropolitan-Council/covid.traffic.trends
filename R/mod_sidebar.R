#' sidebar UI Function
#'
#' @description A shiny Module.
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @noRd
#'
#' @importFrom shiny NS tagList
mod_sidebar_ui <- function(id, pair) {
  ns <- NS(id)
  tagList(
    if (pair == "map") {
      wellPanel(
        p("The map shows the decreases in travel at individual traffic monitoring sites across the Twin Cities Metropolitan area. Traffic monitoring is performed by the Minnesota Department of Transportation (MnDOT) using detectors built into the infrastructure of the roads. These detectors are usually used to estimate congestion along Metro area highways. "),
        mod_user_inputs_ui("map_inputs_ui_1")
      )
    } else if (pair == "plot") {
      wellPanel(
        p("This plot shows the daily relative decrease in freeway travel over time across the Twin Cities metropolitan region after March 1. Points that fall below the zero-line represent decreases in travel relative to typical travel on that day of the year and day of the week. Typical travel is estimated using a statistical analysis of traffic volumes from 2018, 2019, and 2020 prior to March 1. Click and drag your mouse to zoom in on a particular section of the plot.")
      )
    } else if (pair == "table") {
      wellPanel(
        mod_download_ui("download_ui_1")
      )
    } else if (pair == "plot_sys_trends_by_day_part") {
      wellPanel(
        p("This plot shows the daily relative decrease in freeway travel over time across the Twin Cities metropolitan regioin after March 1, 2020. Areas that fall below the zero-line represent decreases in travel relative to typical travel on that day of the year and that day of the week. Typical travel is estimated using a statistical analysis of traffic volumes from 2018, 2019, and 2020 prior to March 1. Click and drag your mouse to zoom in on a particular section of the plot.")
      )
    } else if (pair == "plot_hourly_trends_by_corridor") {
      wellPanel(
        p("This plot shows average traffic volume on the the selected corridor in the selected year by hour during weekdays (Monday through Friday). The dashed line represents the amount of traffic typically observed. Before the pandemic, most corridors had two distinct peaks in traffic: one from 7-9AM, and another from 4-6PM. Post-pandemic, traffic tends to build over the course of the day, with a reduced morning peak. Use the drop-down menus to explore these trends over time and across different corridors. Click and drag your mouse to zoom in on a particular section of the plot. Please note that some corridor months are missing due to incomplete data.
"),
        mod_user_inputs_ui("plot_inputs_ui_1", type = "plot_corridor_hour")
      )
    } else if (pair == "map_station_trends") {
      wellPanel(
        p("The map shows the changes in travel at individual traffic monitoring sites across the Twin Cities Metropolitan area separated out by time of day. Traffic monitoring is performed by the Minnesota Department of Transportation (MnDOT) using detectors built into the infrastructure of the roads. These detectors are usually used to estimate congestion along Metro area highways. "),
        mod_user_inputs_ui("map_day_part_inputs_ui",
          type = "map_station_trends"
        )
      )
    }
  )
}

#' sidebar Server Function
#'
#' @noRd
mod_sidebar_server <- function(input, output, session) {
  ns <- session$ns
}

## To be copied in the UI
# mod_sidebar_ui("sidebar_ui_1")

## To be copied in the server
# callModule(mod_sidebar_server, "sidebar_ui_1")
