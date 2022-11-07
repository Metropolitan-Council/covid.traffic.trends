#' plot UI Function
#'
#' @description A shiny Module.
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @noRd
#' @import plotly
#' @importFrom shiny NS tagList
mod_plot_sys_day_part_ui <- function(id) {
  ns <- NS(id)
  tagList(
    plotlyOutput(ns("plot"), height = "500px")
  )
}

#' plot Server Function
#'
#' @noRd
mod_plot_sys_day_part_server <- function(input, output, session) {
  ns <- session$ns

  output$plot <- renderPlotly({
    plot_ly() %>%
      plotly::add_lines(
        data = covid.traffic.trends::predicted_actual_by_region_day_part,
        x = covid.traffic.trends::predicted_actual_by_region_day_part$date,
        y = covid.traffic.trends::predicted_actual_by_region_day_part$roll_avg,
        color = covid.traffic.trends::predicted_actual_by_region_day_part$day_part,
        # type = "scatter",
        colors = c(councilR::colors$esBlue, councilR::colors$metrostatsDaPurp, councilR::colors$councilBlue),
        mode = "lines",
        hoverinfo = "text",
        text = paste(covid.traffic.trends::predicted_actual_by_region_day_part$hover_text_roll_avg),
        line = list(
          width = 2
        )
      ) %>%
      layout( #-----
        margin = list(l = 10, r = 45, b = 10, t = 10, pad = 10), # l = left; r = right; t = top; b = bottom
        # title ="Metro Area Traffic: Difference between expected and observed",
        annotations = list(
          text = paste(
            "<i>", "Data last updated",
            max(c(
              predicted_actual_by_state$date,
              as.Date(predicted_actual_by_region$date)
            )),
            "</i>"
          ),
          x = 1,
          y = -0.1,
          showarrow = F,
          xref = "paper", yref = "paper",
          xanchor = "right", yanchor = "auto",
          xshift = 0, yshift = -10
        ),
        shapes = list(
          list(
            type = "rect",
            fillcolor = councilR::colors$suppGray,
            opacity = 0.1,
            line = list(color = councilR::colors$suppGray),
            opacity = 0.3,
            x0 = "2020-03-27",
            x1 = "2020-05-18",
            xref = "x",
            y0 = 6,
            y1 = -75,
            yref = "y"
          )
        ),
        hovermode = "closest",
        hoverdistance = "10",
        hoverlabel = list( #----
          font = list(
            size = 20,
            family = font_family_list,
            color = councilR::colors$suppBlack
          ),
          bgcolor = "white",
          stroke = list(
            councilR::colors$suppGray,
            councilR::colors$suppGray,
            councilR::colors$suppGray,
            councilR::colors$suppGray
          ),
          padding = list(l = 5, r = 5, b = 5, t = 5)
        ),
        xaxis = list( #----
          title = "",
          type = "date",
          tickformat = "%b %d",

          ## spikes
          # showspikes = TRUE,
          # spikesnap = "cursor",
          # spikedash = "solid",
          # spikemode = "toaxis+across",
          # spikecolor = councilR::colors$suppBlack,

          zeroline = FALSE,
          showline = FALSE,
          showgrid = TRUE,
          tickfont = list(
            size = 14,
            family = font_family_list,
            color = councilR::colors$suppBlack
          )
        ),
        yaxis = list( #----
          title = list(
            text = "% difference from typical traffic \n",
            font = list(
              size = 14,
              family = font_family_list,
              color = councilR::colors$suppBlack,
              range = c(6, -80)
            )
          ),
          ticksuffix = "%",
          tickfont = list(
            size = 12,
            family = font_family_list,
            color = councilR::colors$suppBlack
          ),
          zeroline = TRUE,
          showline = FALSE,
          showgrid = FALSE
        ),
        legend = list(
          title = list(
            text = "Weekday Day Part",
            font = list(
              size = 16,
              family = font_family_list,
              color = councilR::colors$suppBlack
            )
          ),
          font = list(
            size = 14,
            family = font_family_list,
            color = councilR::colors$suppBlack
          )
        )
      )
  })
}

## To be copied in the UI
# mod_plot_sys_day_part_ui("plot_ui_1")

## To be copied in the server
# callModule(mod_plot_sys_day_part_server, "plot_ui_1")
