#' plot UI Function
#'
#' @description A shiny Module.
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @noRd
#' @import plotly
#' @importFrom shiny NS tagList
mod_plot_corridor_hour_ui <- function(id) {
  ns <- NS(id)
  tagList(
    plotlyOutput(ns("plot"), height = "550px")
  )
}

#' plot Server Function
#'
#' @noRd
mod_plot_corridor_hour_server <- function(input, output, session,
                                          user_inputs = plot_corridor_hour_inputs) {
  ns <- session$ns

  output$plot <- renderPlotly({
    # browser()
    plot_ly() %>%
      plotly::add_trace(
        name = "Observed",
        data = user_inputs$current_corrs,
        x = ~hour_form,
        y = ~actual_volume,
        type = "scatter",
        mode = "lines+markers",
        hoverinfo = "text",
        connectgaps = TRUE,
        text = ~ paste(hover_observe_text),
        line = list(
          width = 2,
          color = councilR::colors$councilBlue
        ),
        marker = list(
          size = 8,
          color = councilR::colors$councilBlue
        )
      ) %>%
      plotly::add_trace(
        name = "Expected",
        data = user_inputs$current_corrs,
        x = ~hour_form,
        y = ~predicted_volume,
        # group = ~corridor_route,  # color = ~corridor_route,
        # name = "MnDOT Metro\nFreeways\n7-day rolling average",
        type = "scatter",
        mode = "lines+markers",
        hoverinfo = "text",
        connectgaps = TRUE,
        text = ~ paste(hover_predict_text),
        line = list(
          width = 2,
          dash = "dot",
          color = councilR::colors$suppBlack
        ),
        marker = list(
          size = 8,
          color = councilR::colors$suppBlack
        )
      ) %>%
      layout(
        margin = list(l = 10, r = 45, b = 10, t = 40, pad = 10), # l = left; r = right; t = top; b = bottom

        title = list(
          text = paste0(
            unique(user_inputs$current_corrs$month_year), " Weekday Traffic",
            " - ", unique(user_inputs$current_corrs$corridor_route)
          ),
          font = list(
            size = 20,
            family = font_family_list,
            color = councilR::colors$suppBlack
          )
        ),
        annotations = list(
          text = paste(
            "<i>", "Data last updated",
            max(c(predicted_actual_by_state$date, as.Date(predicted_actual_by_region$date))),
            "</i>"
          ),
          x = 1,
          y = -0.1,
          showarrow = F,
          xref = "paper", yref = "paper",
          xanchor = "right", yanchor = "auto",
          xshift = 0, yshift = -10
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
        yaxis = list( # -----
          title = "Average total vehicle volume",
          titlefont = list(
            size = 14,
            family = font_family_list,
            color = councilR::colors$suppBlack
          ),
          tickfont = list(
            size = 12,
            family = font_family_list,
            color = councilR::colors$suppBlack
          ),
          zeroline = TRUE,
          showline = FALSE
        ),
        xaxis = list( #----
          title = list(
            text = "Hour",
            font = list(
              size = 14,
              family = font_family_list,
              color = councilR::colors$suppBlack
            )
          ),
          type = "date",
          tickformat = "%I %p",
          # pattern = "hour",
          nticks = 10,
          zeroline = FALSE,
          showline = FALSE,
          showgrid = TRUE,
          tickfont = list(
            size = 14,
            family = font_family_list,
            color = councilR::colors$suppBlack
          )
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
# mod_plot_corridor_hour_ui("plot_ui_1")

## To be copied in the server
# callModule(mod_plot_corridor_hour_server, "plot_ui_1")
