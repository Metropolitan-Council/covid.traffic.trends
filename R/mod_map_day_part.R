#' leaflet UI Function
#'
#' @description A shiny Module.
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @noRd
#' @import leaflet
#' @importFrom shiny NS tagList
mod_map_day_part_ui <- function(id) {
  ns <- NS(id)
  tagList(
    leafletOutput(ns("map"), height = "600px")
  )
}

#' leaflet Server Function
#'
#' @noRd
#' @importFrom purrr map
#' @importFrom dplyr filter

mod_map_day_part_server <- function(input, output, session,
                                    map_inputs) {
  ns <- session$ns

  output$map <- mod_map_base_server(
    input = input,
    output = output,
    session = session
  )

  current_day_part_nodes <- reactive({
    req(map_inputs$select_station_corridor)
    dat <- purrr::map(
      covid.traffic.trends::predicted_actual_node_day_part,
      filter, user_month_year == map_inputs$select_station_month_year
    ) %>%
      purrr::map(filter, corridor_route %in% c(map_inputs$select_station_corridor)) %>%
      purrr::map(filter, day_part == map_inputs$select_station_day_part)
    return(dat)
  })

  update_day_part_map <- reactive({
    dat <- current_day_part_nodes()

    # truncate values at 100% increase in traffic (doubling of traffic volume)
    dat$volume_percent_difference <- ifelse(dat$volume_percent_difference >= 1, 1)

    col_pal <- colorBin( # palette generated with Chroma.js (#ee3124 to #0054a4)
      palette = c(
        "#840000", "#bd1712",
        "#ed4434", "#fe8466",
        "#fac0b1", "#accdfe",
        "#78a3e8", "#497acd",
        "#2353a2", "#002f77"
      ),
      domain = c(-100:100), bins = 10, # suggest white is zero, purple is decrease, orange is increase
      reverse = T
    )


    map <- leafletProxy("map", session = session) %>%
      clearGroup("Freeway Segment") %>%
      clearGroup("Entrance") %>%
      clearGroup("Exit") %>%
      addCircleMarkers(
        data = dat$Freeway_Segment,
        lng = ~r_node_lon,
        lat = ~r_node_lat,
        color = ~ col_pal(volume_percent_difference * 100),
        stroke = T,
        fillOpacity = 0.75,
        popup = ~ paste(hover_text),
        radius = 3,
        group = "Freeway Segment",
        options = leafletOptions(pane = "points")
      ) %>%
      addCircleMarkers(
        data = dat$Entrance,
        lng = ~r_node_lon,
        lat = ~r_node_lat,
        color = ~ col_pal(volume_percent_difference * 100),
        stroke = T,
        fillOpacity = 0.75,
        popup = ~ paste(hover_text),
        radius = 3,
        group = "Entrance",
        options = leafletOptions(pane = "points")
      ) %>%
      addCircleMarkers(
        data = dat$Exit,
        lng = ~r_node_lon,
        lat = ~r_node_lat,
        color = ~ col_pal(volume_percent_difference * 100),
        stroke = T,
        fillOpacity = 0.75,
        popup = ~ paste(hover_text),
        radius = 3,
        group = "Exit",
        options = leafletOptions(pane = "points")
      ) %>%
      addLegend(
        position = "topright",
        pal = col_pal,
        values = dat$volume_percent_difference * 100,
        layerId = "Nodes",
        title = paste(
          "% Change", "<br>",
          "from Expected"
        ),
        labFormat = labelFormat(suffix = "%")
      )

    return(map)
  })

  observeEvent(map_inputs$select_station_corridor, ignoreInit = FALSE, {
    # print(map_inputs$corridor)
    # browser()
    update_day_part_map()
  })

  observeEvent(map_inputs$select_station_month_year, {
    update_day_part_map()
  })

  observeEvent(map_inputs$select_station_day_part, {
    update_day_part_map()
  })
}

## To be copied in the UI
# mod_map_day_part_ui("leaflet_ui")

## To be copied in the server
# callModule(mod_map_day_part_server, "leaflet_ui")
