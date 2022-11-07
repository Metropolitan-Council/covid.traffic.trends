#' plot UI Function
#'
#' @description A shiny Module.
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @noRd
#' @import plotly
#' @importFrom shiny NS tagList
mod_plot_main_ui <- function(id) {
  ns <- NS(id)
  tagList(
    plotlyOutput(ns("plot"), height = "500px")
  )
}

#' plot Server Function
#'
#' @noRd
mod_plot_main_server <- function(input, output, session) {
  ns <- session$ns

  output$plot <- renderPlotly({
    plot_ly() %>%
      plotly::add_trace(
        type = "scatter",
        data = covid.traffic.trends::predicted_actual_by_region["doy" > 60 & "year" == 2020],
        x = covid.traffic.trends::predicted_actual_by_region$date,
        y = covid.traffic.trends::predicted_actual_by_region$volume_difference_percent,
        name = "MnDOT Metro\nFreeways\n(Daily Data)\n",
        mode = "markers",
        marker = list(
          color = councilR::colors$councilBlue,
          size = 6,
          opacity = 0.7
        ),
        hoverinfo = "text",
        text = paste(predicted_actual_by_region$hover_text),
        showlegend = TRUE,
        visible = "legendonly"
      ) %>%
      plotly::add_trace(
        data = covid.traffic.trends::predicted_actual_by_region,
        x = covid.traffic.trends::predicted_actual_by_region$date,
        y = covid.traffic.trends::predicted_actual_by_region$roll_avg,
        name = "MnDOT Metro\nFreeways\n(7-day Trend)",
        type = "scatter",
        mode = "lines",
        hoverinfo = "text",
        text = paste(covid.traffic.trends::predicted_actual_by_region$hover_text_roll_avg),
        line = list(
          width = 2,
          color = councilR::colors$councilBlue
        )
      ) %>%
      # plotly::add_trace(
      #   data = covid.traffic.trends::predicted_actual_by_state,
      #   x = covid.traffic.trends::predicted_actual_by_state$date,
      #   y = covid.traffic.trends::predicted_actual_by_state$volume_difference_percent,
      #   name = "MnDOT Statewide\n(105 Stations)\n",
      #   type = "scatter",
      #   mode = "lines+markers",
      #   hoverinfo = "text",
      #   text = paste(covid.traffic.trends::predicted_actual_by_state$hover_text),
      #   line = list(
      #     width = 2,
      #     color = councilR::colors$suppBlack,
      #     dash = "dot"
      #   ),
      #   marker = list(
      #     color = councilR::colors$suppBlack,
      #     size = 6
      #   ),
      #   visible = "legendonly"
      # ) %>%
      # plotly::add_trace(
      #   data = covid.traffic.trends::predicted_actual_by_state,
      #   x = covid.traffic.trends::predicted_actual_by_state$date,
      #   y = covid.traffic.trends::predicted_actual_by_state$roll_avg,
      #   name = "MnDOT Statewide\n7-day rolling average",
      #   type = "scatter",
      #   mode = "lines",
      #   hoverinfo = "text",
      #   text = paste(covid.traffic.trends::predicted_actual_by_state$hover_text_roll_avg),
      #   line = list(
      #     width = 2,
      #     color = councilR::colors$suppBlack
      #   )
      #   # marker = list(
      #   #   size = 0,
      #   #   color = councilR::colors$suppBlack
      #   # )
      # ) %>%
      layout( #-----
        margin = list(l = 10, r = 45, b = 10, t = 10, pad = 10), # l = left; r = right; t = top; b = bottom
        # title ="Metro Area Traffic: Difference between expected and observed",
        annotations = list(
          text = paste(
            "<br><br>",
            "<i>", "Data last updated",
            max(c(predicted_actual_by_state$date, as.Date(predicted_actual_by_region$date))),
            "</i>"
          ),
          x = 1,
          y = -0.1,
          showarrow = F,
          xref = "paper", yref = "paper",
          xanchor = "right", yanchor = "auto",
          xshift = 0, yshift = -25
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
            y0 = 12,
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
          tickformat = "%b %d\n%Y",
          range = list(
            "2020-01-03",
            max(predicted_actual_by_region$date)
          ),
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
          title = "% difference from typical traffic \n",
          titlefont = list(
            size = 14,
            family = font_family_list,
            color = councilR::colors$suppBlack,
            range = c(12, -80)
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
# mod_plot_main_ui("plot_ui_1")

## To be copied in the server
# callModule(mod_plot_main_server, "plot_ui_1")
