## code to prepare `predicted_actual` and node-level dataset series goes here
library(covid.traffic.trends)
library(dplyr)
library(janitor)
library(stringr)
library(zoo)
library(usethis)
library(ggplot2)
library(councilR)
library(showtext)
library(DBI)
library(sf)
library(data.table)
library(DBI)
library(lubridate)


#Connecting to the SQLdatabase -------------------------------
source("data-raw/_db_connect.R")
con <- db_connect()

## Load Detector Configuration -----
#### at the sensor (detector) level (most specific) ----
sensor_config_raw <- DBI::dbGetQuery(con, "select * from rtmc_configuration")

sensor_config <- sensor_config_raw %>%
  janitor::clean_names() %>%
  dplyr::filter(node_n_type != "Intersection",
         node_n_type != "") %>%
  dplyr::mutate(
    # omg this nested string replace function is ugly, but it works.
    corridor_route = stringr::str_replace(
      stringr::str_replace(
        stringr::str_replace(
          stringr::str_replace(corridor_route, "\\.", " "), "\\.", " "),
        "T H",
        "TH"
      ),
      "U S",
      "US"
    ),
    node_type = dplyr::case_when(node_n_type == "Station" ~ "Freeway Segment",
                          TRUE ~ node_n_type)
  ) %>%
  dplyr::select(-date) # download date of configuration file

#### at the node level (several sensors per node) ----
node_config <-
  sensor_config %>%
  dplyr::select(
    # get rid of detector-level data:
   -dplyr::contains("detector"),
    # extraneous data about the nodes:
    -node_lanes,
    -node_shift,
    -node_attach_side,
   -id
  ) %>%
  # now just get the nodes.
  unique()

#### spatial file for corridors ----
corridors <- covid.traffic.trends::nodes %>%
  dplyr::group_by(corridor_route) %>%
  dplyr::arrange(r_node_name) %>%
  dplyr::summarize(do_union = T) %>%
  sf::st_cast("LINESTRING")

## Daily Data: By Node -----
raw_predicted_actual_by_node <-
  DBI::dbGetQuery(con, "SELECT * FROM RTMC_DAILY_NODE_DIFF_NOW")

predicted_actual_by_node <- raw_predicted_actual_by_node %>%
  dplyr::rename(
    "node_name" = "NODE_NAME",
    "date" = "DATA_DATE",
    "actual_volume" = "TOTAL_VOLUME",
    "predicted_volume" = "VOLUME_PREDICT",
    "volume_difference_absolute" = "VOLUME_DIFF"
  ) %>%
  dplyr::mutate(date := as.Date(date),
    node_id = stringr::str_remove_all(node_name, "rnd_")
  ) %>%
  dplyr::mutate(volume_difference_percent = (volume_difference_absolute / predicted_volume) * 100) %>%
  dplyr::left_join(node_config, by = "node_name") %>%
  dplyr::filter(
    node_n_type != "Intersection",
    node_n_type != "",
    date >= "2020-03-01"
  ) %>%
  dplyr::mutate(
    hover_text = paste(
      sep = "",
      "<b>",
      format.Date(date, "%A, %B %d, %Y"),
      "</b>",
      "<br>",
      node_type,
      " on ",
      corridor_route,
      " at ",
      node_label,
      " (Node ",
      node_id,
      ")",
      "<br>",
      round(volume_difference_percent),
      "%"
    ),
    District = "MnDOT Metro Freeways",
    month_year = format(date, "%B %Y")
  )

unique_corridors <- unique(predicted_actual_by_node$corridor_route)

usethis::use_data(unique_corridors,
                  overwrite = TRUE,
                  compress = "xz", internal = FALSE
)

predicted_actual_by_node <- predicted_actual_by_node %>%
  dplyr::filter(node_type != "") %>%
  dplyr::group_by(node_type) %>%
  dplyr::group_split(.keep = TRUE)

names(predicted_actual_by_node) <-
  c("Entrance", "Exit", "Freeway_Segment")

usethis::use_data(predicted_actual_by_node,
  overwrite = TRUE,
  compress = "xz", internal = FALSE
)




## Daily Data: Entire Region -----
predicted_actual_by_region <-
  DBI::dbGetQuery(con, "SELECT * FROM RTMC_DAILY_SYSTEM_DIFF_NOW") %>%
  dplyr::rename(
    "date" = "DATA_DATE",
    "actual_volume" = "TOTAL_VOLUME",
    "predicted_volume" = "TOTAL_PREDICTED_VOLUME",
    "volume_difference_absolute" = "TOTAL_VOLUME_DIFF"
  ) %>%
  dplyr::mutate(
    date = as.Date(date),
    volume_difference_percent =
      round(100 * volume_difference_absolute / predicted_volume, 2)
  ) %>%
  dplyr::mutate(
    District = "MnDOT Metro Freeways",
    weekday = format.Date(date, "%A")
  ) %>%
  dplyr::arrange(date) %>%
  dplyr::mutate(
    roll_avg = zoo::rollmean(volume_difference_percent, k = 7, fill = NA),
    month_year = format.Date(date, "%B %Y"),
    hover_text_roll_avg = paste(
      sep = "",
      "<b>",
      format.Date(date, "%A, %B %d, %Y"),
      "</b>",
      "<br>",
      "Metro 7-day average ",
      "<br>",
      round(roll_avg, digits = 1),
      "%"
    ),
    hover_text = paste(
      sep = "",
      "<b>",
      format.Date(date, "%A, %B %d, %Y"),
      "</b>",
      "<br>",
      round(volume_difference_percent, digits = 1),
      "%"
    )
  )

usethis::use_data(predicted_actual_by_region,
  overwrite = TRUE,
  compress = "xz", internal = FALSE
)

## Hourly Data: By Node -----
# this data aggregates at the monthly level instead of daily level to keep file size reasonable
hr_node_diff <-
  DBI::dbGetQuery(con, "SELECT * FROM RTMC_HOURLY_NODE_DIFF_MON_NOW") %>%
  dplyr::rename(
    "node_name" = "NODE_NAME",
    "year" = "DATA_YEAR",
    "month" = "DATA_MONTH",
    "hour" = "DATA_HOUR",
    "actual_volume" = "TOTAL_VOLUME",
    "predicted_volume" = "VOLUME_PREDICT"
  ) %>%
  dplyr::left_join(node_config, by = c("node_name" = "node_name")) %>%
  dplyr::mutate(month_year = paste(month.name[month], year))


hr_node_diff <- left_join(hr_node_diff, nodes)

predicted_actual_node_day_part <- hr_node_diff %>%
  dplyr::mutate(
    day_part = dplyr::case_when(
      hour >= 7 & hour <= 9 ~ "Morning, 7-9AM",
      hour >= 11 & hour <= 13 ~ "Midday, 11AM-1PM",
      hour >= 16 & hour <= 18 ~ "Evening, 4-6PM"
    ) %>%
      factor(levels = c("Morning, 7-9AM", "Midday, 11AM-1PM", "Evening, 4-6PM")),
    day_part_short = dplyr::case_when(
      hour >= 7 & hour <= 9 ~ "morning",
      hour >= 11 & hour <= 13 ~ "midday",
      hour >= 16 & hour <= 18 ~ "evening"
    ),
    day_type = "Weekday",
    node_id = stringr::str_remove_all(node_name, "rnd_")
  ) %>%
  dplyr::filter(
    node_n_type != "Intersection",
    node_n_type != ""
  ) %>%
  dplyr::group_by(
    day_part, day_type, day_part_short, month_year,
    node_lat, node_lon,
    node_name, node_id, node_n_type, node_label, corridor_route
  ) %>%
  dplyr::summarize(across(c(actual_volume, predicted_volume), sum)) %>%
  dplyr::ungroup() %>%
  dplyr::group_by(day_part, node_name) %>%
  dplyr::mutate(
    rollmean_sum = zoo::rollmeanr(actual_volume, k = 7, fill = NA),
    rollmean_pred = zoo::rollmeanr(predicted_volume, k = 7, fill = NA)
  ) %>%
  dplyr::mutate(
    rollmean_percent = (rollmean_sum - rollmean_pred) / rollmean_pred,
    volume_percent_difference = (actual_volume - predicted_volume) / predicted_volume
  ) %>%
  dplyr::filter(
    !is.na(day_part),
    day_type == "Weekday"
  ) %>%
  dplyr::mutate(
    node_type = dplyr::case_when(
      node_n_type == "Station" ~ "Freeway Segment",
      TRUE ~ node_n_type
    ),
    user_month_year = factor(month_year,
      levels = c(
        unlist(lapply(c(2020:2024), function(x) paste(month.name, x)))),
      ordered = TRUE
    ),
    hover_text = paste(
      sep = "",
      "<b>",
      month_year,
      "</b>",
      "<br>",
      day_part,
      "<br>",
      node_type,
      " on ",
      corridor_route,
      " at ",
      node_label,
      " (Node ",
      node_id,
      ")",
      "<br>",
      round(volume_percent_difference * 100, digits = 1),
      "%"
    ),
  ) %>%
  group_by(node_type) %>%
  group_split()

names(predicted_actual_node_day_part) <- c("Entrance", "Exit", "Freeway_Segment")

usethis::use_data(predicted_actual_node_day_part,
  overwrite = TRUE,
  compress = "xz", internal = FALSE
)

# Hourly Data: By Node, Aggregated to Day part ------------------------------------------
predicted_actual_corridor_day_part <- hr_node_diff %>%
  dplyr::mutate(
    day_part = case_when(
      hour >= 7 & hour <= 9 ~ "Morning, 7-9AM",
      hour >= 11 & hour <= 13 ~ "Midday, 11AM-1PM",
      hour >= 16 & hour <= 18 ~ "Evening, 4-6PM"
    ) %>%
      factor(levels = c("Morning, 7-9AM", "Midday, 11AM-1PM", "Evening, 4-6PM")),
    day_part_short = case_when(
      hour >= 7 & hour <= 9 ~ "morning",
      hour >= 11 & hour <= 13 ~ "midday",
      hour >= 16 & hour <= 18 ~ "evening"
    ),
    # year = "2021",
    month_year = paste(month.name[month], year),
    day_type = "Weekday"
  ) %>%
  dplyr::group_by(day_part, day_type, day_part_short, month_year, year, corridor_route) %>%
  dplyr::summarize(across(c(actual_volume, predicted_volume), sum)) %>%
  dplyr::ungroup() %>%
  dplyr::group_by(day_part, corridor_route) %>%
  dplyr::mutate(
    rollmean_sum = zoo::rollmeanr(actual_volume, k = 7, fill = NA),
    rollmean_pred = zoo::rollmeanr(predicted_volume, k = 7, fill = NA)
  ) %>%
  dplyr::mutate(
    rollmean_percent = (rollmean_sum - rollmean_pred) / rollmean_pred,
    volume_percent_difference = (actual_volume - predicted_volume) / predicted_volume
  ) %>%
  dplyr::filter(
    !is.na(day_part),
    day_type == "Weekday"
  ) %>%
  dplyr::mutate(
    hover_observe_text = stringr::str_wrap(paste0(
      "<b>", month_year, " ", "</b>",
      ", the ", "<b>observed</b> ", "average total weekday volume in the ",
      "<b>", day_part_short, "</b>", " was ",
      format(round(actual_volume), big.mark = ","), " vehicles"
    ), width = 30),
    hover_predict_text = stringr::str_wrap(paste0(
      "<b>", month_year, " ", year, "</b>",
      ", the ", "<b>expected</b> ", " average total weekday volume in the ",
      "<b>", day_part_short, "</b>", " was ",
      format(round(predicted_volume), big.mark = ","), " vehicles"
    ), width = 30)
  )

usethis::use_data(predicted_actual_corridor_day_part,
  overwrite = TRUE,
  compress = "xz", internal = FALSE
)

# Hourly Data: By Corridor, Aggregated to Hour -----
predicted_actual_corridor_hour <- hr_node_diff %>%
  dplyr::filter(node_n_type == "Station") %>%
  dplyr::mutate(
    month_year = paste(month.name[month], year),
    day_type = "Weekday"
  ) %>%
  dplyr::group_by(hour, day_type, month_year, year, corridor_route) %>%
  dplyr::summarize(across(c(actual_volume, predicted_volume), sum)) %>%
  dplyr::ungroup() %>%
  dplyr::mutate(
    volume_percent_difference = (actual_volume - predicted_volume) / predicted_volume
  ) %>%
  dplyr::filter(
    day_type == "Weekday"
  ) %>%
  dplyr::mutate(
    user_month_year = factor(month_year,
                             levels = c(
                               unlist(lapply(c(2020:2024), function(x) paste(month.name, x)))),
                             ordered = TRUE
    ),
    hour_form = paste0(hour, ":00") %>% lubridate::hm() %>% lubridate::as_datetime(),
    hover_observe_text = stringr::str_wrap(paste0(
      "<b>", month_year, "</b>",
      ", the ", "<b>observed</b> ", "total weekday volume at ",
      "<b>", format(hour_form, "%I %p"), "</b>", " was ",
      format(round(actual_volume, -3), big.mark = ","), " vehicles"
    ), width = 30),
    hover_predict_text = stringr::str_wrap(paste0(
      "<b>", month_year, "</b>",
      ", the ", "<b>expected</b> ", " average total weekday volume at ",
      "<b>", format(hour_form, "%I %p"), "</b>", " was ",
      format(round(predicted_volume, -3), big.mark = ","), " vehicles"
    ), width = 30)
  ) %>%
  data.table::as.data.table()

usethis::use_data(predicted_actual_corridor_hour,
  overwrite = TRUE,
  compress = "xz", internal = FALSE
)

# diagnostic plot
predicted_actual_corridor_hour %>%
  dplyr::filter(corridor_route == "TH 280") %>%
  ggplot2::ggplot(aes(x = hour)) +
  geom_line(aes(y = actual_volume), color = "blue") +
  geom_line(aes(y = predicted_volume), color = "black") +
  facet_wrap(~user_month_year) +
  theme_void() +
  theme(panel.grid = element_blank()) + 
  ggtitle("Predicted/Acutal by Hour, TH 280")

# Hourly Data, Entire System -----
hr_system_diffs <- 
  DBI::dbGetQuery(con, "SELECT * FROM RTMC_HOURLY_SYSTEM_DIFF_NOW") %>%
  dplyr::rename(
    "date" = "DATA_DATE",
    "hour" = "DATA_HOUR",
    "actual_volume" = "TOTAL_VOLUME",
    "predicted_volume"  = "TOTAL_PREDICTED_VOLUME",
    "volume_difference_absolute" = "TOTAL_VOLUME_DIFF"
  ) %>%
  dplyr::mutate(date = as.Date(date)) %>%
  dplyr::mutate(dow = lubridate::wday(date, label = T, abbr = F))

#### Aggregated to Day part -----
predicted_actual_by_region_day_part <- hr_system_diffs %>%
  dplyr::mutate(
    volume_percent_difference = (volume_difference_absolute / predicted_volume) * 100,
    date = lubridate::ymd(date),
    month_year = month.name[lubridate::month(date)],
    day_part = dplyr::case_when(
      hour >= 7 & hour <= 9 ~ "Morning, 7-9AM",
      hour >= 11 & hour <= 13 ~ "Midday, 11AM-1PM",
      hour >= 16 & hour <= 18 ~ "Evening, 4-6PM"
    ) %>%
      factor(levels = c("Morning, 7-9AM", "Midday, 11AM-1PM", "Evening, 4-6PM")),
    day_part_short = dplyr::case_when(
      hour >= 7 & hour <= 9 ~ "morning",
      hour >= 11 & hour <= 13 ~ "midday",
      hour >= 16 & hour <= 18 ~ "evening"
    ),
    District = "MnDOT Metro Freeways",
    weekday = format.Date(date, "%A"),
    day_type = dplyr::case_when(
      weekday %in% c("Saturday", "Sunday") ~ "Weekend",
      TRUE ~ "Weekday"
    )
  ) %>%
  dplyr::filter(
    !is.na(day_part),
    day_type == "Weekday"
  ) %>%
  dplyr::group_by(date, dow, day_part, day_part_short, District) %>%
  # add up the volume:
  dplyr::summarize(
    actual_volume = sum(actual_volume),
    predicted_volume = sum(predicted_volume),
    volume_difference_absolute = sum(volume_difference_absolute)
  ) %>%
  dplyr::ungroup() %>%
  dplyr::arrange(date) %>%
  dplyr::group_by(day_part) %>%
  dplyr::mutate(
    roll_avg_predicted = zoo::rollmeanr(predicted_volume, k = 7, fill = NA),
    roll_avg_observed = zoo::rollmeanr(actual_volume, k = 7, fill = NA),
    roll_avg = ((roll_avg_observed - roll_avg_predicted) / roll_avg_predicted * 100),
    month_year = format(date, "%B %Y"),
    hover_text_roll_avg = paste(
      sep = "", "<b>", format.Date(date, "%A, %B %d, %Y"), "</b>", "<br>",
      day_part, "<br>",
      "Metro 7-day average ", "<br>", round(roll_avg, digits = 1), "%"
    ),
    hover_text = paste(
      sep = "", "<b>", format.Date(date, "%A, %B %d, %Y"), "</b>", "<br>",
      day_part, "<br>",
      round(volume_difference_absolute, digits = 1), "%"
    )
  )

usethis::use_data(predicted_actual_by_region_day_part,
  overwrite = TRUE,
  compress = "xz", internal = FALSE
)


## write new plot -----
showtext::showtext_auto()

static_plot <-
  ggplot() +
  theme_minimal() +
  geom_line(
    data = predicted_actual_by_region,
    aes(
      x = date,
      y = roll_avg,
      color = "7-Day Rolling Average",
      group = "7-Day Rolling Average"
    )
  ) +
  geom_point(
    data = predicted_actual_by_region,
    aes(
      x = date,
      y = volume_difference_percent,
      color = "Daily Difference"
    ),
    # color = councilR::colors$councilBlue,
    size = 1.1,
    shape = 16,
    alpha = 0.6
  ) +
  geom_hline(yintercept = 0) +
  scale_color_manual(
    guide = guide_legend(override.aes = list(
      linetype = c("solid", "blank"),
      shape = c(NA, 16),
      size = c(1, 2)
    )),
    values = c(
      councilR::colors$councilBlue,
      councilR::colors$councilBlue
    )
  ) +
  scale_y_continuous(
    limits = c(-70, 10),
    breaks = seq(10, -70, by = -10),
    labels = scales::label_comma(suffix = "%")
  ) +
  facet_grid(~year(date), 
             space="free_x", scales="free_x", switch="x") +
  scale_x_date(
    # limits = c(
    #   as.Date("2020-01-03"),
    #   max(predicted_actual_by_region$date)
    # ),
    expand = c(0,0),
    date_breaks = "2 months",
    date_minor_breaks = "months",
    date_labels = "%b") + 
  
  labs(
    y = "% difference from typical traffic",
    x = "",
    color = "",
    title = "Metro area freeway traffic remains below pre-pandemic levels in 2022",
    subtitle = "Difference from pre-pandemic traffic (%)",
    caption = paste0("Last updated ", max(predicted_actual_by_region$date))
  ) +
  councilR::theme_council(
    use_showtext = T
  ) +
  theme(
    plot.background = element_rect(
      fill = "white",
      linetype = "blank"
    ),
    legend.position = "bottom",
    plot.title.position = "plot",
    axis.title.x  = element_blank(),
        axis.title.y  = element_blank(),
        axis.text.x = element_text(size = 36, color = "black"),
        axis.text.y = element_text(size = 36, color = "black"),
        plot.caption = element_text(size = 36, color = "black"),
        plot.title = element_text(size = 64, color = "black"),
        plot.subtitle = element_text(size = 48, color = "black"),
        legend.text = element_text(size = 48, color = "black"),
        strip.placement = "outside",
        panel.grid.major = element_line(size = 0.1, color = "gray50"),
        panel.grid.minor = element_line(size = 0.05, color = "gray70"),
        strip.text = element_text(size = 48, color = "black"),
        strip.background = element_blank(),
        panel.spacing=unit(0,"cm"))


ggsave("inst/app/www/predicted_actual_plot.png",
  static_plot,
  height = 5, width = 9, units = "in"
)
