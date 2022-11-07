#' The application User-Interface
#'
#' @param request Internal parameter for \code{shiny}.
#'     DO NOT REMOVE.
#' @import shiny
#' @import council.skeleton
#' @noRd
app_ui <- function(request) {
  tagList(
    # Leave this function for adding external resources
    golem_add_external_resources(),
    # List the first level UI elements here
    fluidPage(
      council.skeleton::sk_page(
        council.skeleton::sk_header(
          "Freeway Travel Trends",
          shiny::h4("Explore traffic trends across the Twin Cities freeway system.")
        ),
        council.skeleton::sk_nav(
          council.skeleton::sk_nav_item("map_plot", "Map & Plot"),
          council.skeleton::sk_nav_item("morning_evening_trends", "Hourly Trends"),
          council.skeleton::sk_nav_item("download", "Download Data"),
          council.skeleton::sk_nav_item("about", "About")
        ),
        council.skeleton::sk_row(
          id = "map_plot",
          width = 12,
          h5("Traffic on the Twin Cities freeway system is nearing typical levels"),
          council.skeleton::sk_col("sk_plot_col",
            width = 12,
            council.skeleton::sk_col("sk_sidebar_plot",
              width = 3,
              mod_sidebar_ui("sidebar_ui_plot", pair = "plot")
            ),
            council.skeleton::sk_col("sk_plot",
              width = 9,
              mod_plot_main_ui("plot_ui_1")
            )
          ),
          h5("Traffic trends vary across the freeway system"),
          council.skeleton::sk_col("sk_map_col",
            width = 12,
            council.skeleton::sk_col("sk_sidebar_map",
              width = 3,
              mod_sidebar_ui("sidebar_ui_map", pair = "map")
            ),
            council.skeleton::sk_col("sk_map",
              width = 9,
              mod_map_main_ui("leaflet_ui")
            )
          )
        ),

        ## hourly trends tab-----
        council.skeleton::sk_row(
          id = "morning_evening_trends",
          h5("A deeper dive: traffic trends by time of day"),
          p("During COVID-19, telecommuting rates increased dramatically, while social and recreational travel decreased. Meanwhile, workers that could not do their jobs remotely – many working jobs with shifts outside of the 9-5 office commute schedule – continued to travel to work. Businesses closed, re-opened, and shifted their services. These changes have all had a profound effect not only on how much we travel, but also when we travel. Use this interactive to explore these trends on the metro freeway system."),

          # system trends by time of day -----

          sk_col("sk_sys_trends_by_day_part",
            width = 12,
            sk_col("sk_sidebar_sys_trends_by_day_part",
              width = 3,
              mod_sidebar_ui("sidebar_ui_plot_sys_trends_by_day_part",
                pair = "plot_sys_trends_by_day_part"
              )
            ),
            sk_col("sk_plot_sys_trends_by_day_part",
              width = 9,
              mod_plot_sys_day_part_ui("plot_sys_trends_day_part_ui_1")
            )
          ),
          h5("Explore weekday hourly trends by corridor"),

          # hourly trends by corridor -----
          sk_col("sk_hourly_trends_by_corridor",
            width = 12,
            sk_col("sk_sidebar_hourly_trends_by_corridor",
              width = 3,
              mod_sidebar_ui("sidebar_ui_plot_hourly_trends_by_corridor",
                pair = "plot_hourly_trends_by_corridor"
              )
            ),
            sk_col("sk_plot_hourly_trends_by_corridor",
              width = 9,
              mod_plot_corridor_hour_ui("plot_corridor_hour_1")
            )
          ),
          h5("Weekday station traffic trends across the metro"),

          # station trends by time of day -----
          sk_col("sk_station_trends",
            width = 12,
            sk_col("sk_sidebar_map_station_trends",
              width = 3,
              mod_sidebar_ui("sidebar_ui_map_station_trends",
                pair = "map_station_trends"
              )
            ),
            sk_col("sk_map_station_trends",
              width = 9,
              mod_map_day_part_ui("map_day_part_ui_1")
            )
          )
        ),

        ## download tab -----
        council.skeleton::sk_row(
          id = "download",
          sk_col("sk_sidebar_download",
            width = 3,
            h5("Download the most recent data"),
            mod_sidebar_ui("sidebar_ui_table", pair = "table"),
          ),
          sk_col("sk_table",
            width = 9,
            mod_table_ui("table_ui_1")
          )
        ),



        ## About tab -----
        council.skeleton::sk_row(
          id = "about",
          mod_about_ui("about_ui")
        ),
        tags$div("For an accessible version of this information, please contact us at",
          tags$a(href = "mailto:public.info@metc.state.mn.us", "public.info@metc.state.mn.us"),
          style = "font-size: 1.5rem;
             display: block;
             text-align: right;
             padding: 1%;", align = "right"
        ),
        tags$footer(
          #----
          tags$a(
            href = "https://metrocouncil.org", target = "_blank",
            img(src = "www/main-logo.png", align = "right", style = "padding: 1%")
          )
          # tags$div(
          #   tags$a(href="https://github.com/Metropolitan-Council/loop-sensor-trends", target="_blank",
          #          icon(name = "github", lib = "font-awesome"))
          # )
        )
      )
    )
  )
}

#' Add external Resources to the Application
#'
#' This function is internally used to add external
#' resources inside the Shiny application.
#'
#' @import shiny
#' @importFrom golem add_resource_path activate_js favicon bundle_resources
#' @noRd
golem_add_external_resources <- function() {
  add_resource_path(
    "www", app_sys("app/www")
  )

  suppressDependencies()
  tags$head(
    includeHTML("inst/app/www/google-analytics.html"),
    favicon(),
    bundle_resources(
      path = app_sys("app/www"),
      app_title = "Twin Cities Freeway Traffic Trends"
    )
    # Add here other external resources
    # for example, you can add shinyalert::useShinyalert()
  )
}
