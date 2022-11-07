#' map_base UI Function
#'
#' @description A shiny Module.
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @noRd
#'
#' @importFrom shiny NS tagList
mod_map_base_ui <- function(id) {
  ns <- NS(id)
  tagList()
}

#' map_base Server Function
#'
#' @noRd
mod_map_base_server <- function(input, output, session) {
  ns <- session$ns


  output$ns <- leaflet::renderLeaflet(quoted = TRUE, {
    rlang::quo({
      # browser()
      leaflet() %>%
        fitBounds(-93.521749, 44.854051, -92.899649, 45.081892) %>%
        # fit boundary of map to metro area
        addProviderTiles("CartoDB.DarkMatter",
          group = "Carto DarkMatter"
        ) %>%
        addProviderTiles("CartoDB.Positron",
          group = "Carto Positron"
        ) %>%
        addMapPane("polygons", zIndex = 410) %>%
        addMapPane("points", zIndex = 420) %>%
        addPolygons(
          data = covid.traffic.trends::mn_counties,
          group = "County outline",
          fill = NA,
          color = "darkgray",
          weight = 1
        ) %>%
        hideGroup("County outline") %>%
        addLayersControl(
          position = "bottomright",
          baseGroups = c(
            "Carto Positron",
            "Carto DarkMatter"
          ),
          overlayGroups = c(
            "Freeway Segment",
            "Entrance",
            "Exit",
            "County outline"
          ),
          options = layersControlOptions(collapsed = T)
        )
    })
  })
}

## To be copied in the UI
# mod_map_base_ui("map_base_ui_1")

## To be copied in the server
# callModule(mod_map_base_server, "map_base_ui_1")
