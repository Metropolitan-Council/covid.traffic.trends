#' leaflet UI Function
#'
#' @description A shiny Module.
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @noRd
#' @import leaflet
#' @importFrom shiny NS tagList
mod_map_main_ui <- function(id) {
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

mod_map_main_server <- function(input, output, session,
                                map_inputs) {
  ns <- session$ns
  output$map <- mod_map_base_server(
    input = input,
    output = output,
    session = session
  )

  current_nodes <- reactive({
    req(map_inputs$date)
    dat <- purrr::map(
      covid.traffic.trends::predicted_actual_by_node,
      filter, date == map_inputs$date
    ) %>%
      purrr::map(filter, corridor_route %in% map_inputs$corridor_route)

    return(dat)
  })

  update_map <- reactive({
    dat <- current_nodes()

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
        color = ~ col_pal(volume_difference_percent),
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
        color = ~ col_pal(volume_difference_percent),
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
        color = ~ col_pal(volume_difference_percent),
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
        values = dat$volume_difference_percent,
        layerId = "Nodes",
        title = paste(
          "% Change", "<br>",
          "from Expected"
        ),
        labFormat = labelFormat(suffix = "%")
      )

    return(map)
  })

  observeEvent(map_inputs$corridor, {
    # print(map_inputs$corridor)
    # browser()
    update_map()
  })



  observeEvent(map_inputs$date, {
    update_map()
  })
}

## To be copied in the UI
# mod_map_main_ui("leaflet_ui")

## To be copied in the server
# callModule(mod_map_main_server, "leaflet_ui")
