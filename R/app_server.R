#' The application server-side
#'
#' @param input,output,session Internal parameters for {shiny}.
#'     DO NOT REMOVE.
#' @import shiny
#' @noRd
app_server <- function(input, output, session) {
  # List the first level callModules here
  callModule(mod_sidebar_server, "sidebar_ui_map")
  callModule(mod_sidebar_server, "sidebar_ui_plot")

  map_inputs <- callModule(mod_user_inputs_server, "map_inputs_ui_1")
  plot_corridor_hour_inputs <- callModule(mod_user_inputs_server, "plot_inputs_ui_1")

  map_day_part_inputs <- callModule(mod_user_inputs_server, "map_day_part_inputs_ui")

  callModule(mod_map_main_server, "leaflet_ui",
    map_inputs = map_inputs
  )

  callModule(mod_plot_main_server, "plot_ui_1")


  callModule(mod_plot_sys_day_part_server, "plot_sys_trends_day_part_ui_1")
  callModule(mod_plot_corridor_hour_server, "plot_corridor_hour_1",
    user_inputs = plot_corridor_hour_inputs
  )

  callModule(mod_map_day_part_server, "map_day_part_ui_1",
    map_inputs = map_day_part_inputs
  )


  # downloads -----
  callModule(mod_table_server, "table_ui_1")
  callModule(mod_download_server, "download_ui_1")
}
