## code to prepare `predicted_actual` and node-level dataset series goes here
library(covid.traffic.trends)
library(sf)
library(data.table)
library(dplyr)
library(DBI)
library(lubridate)
# For Database Connection:
library(ROracle)
library(keyring)
library(ggplot2)
library(odbc)

#Connecting to the SQLdatabase -------------------------------
library(DBI)
# custom R Script from Liz Roten to connect
source("_db_connect.R")

con <- db_connect()
## Connect to the Database -----
connect.string <- "(DESCRIPTION=(ADDRESS_LIST = (ADDRESS = (PROTOCOL = TCP)(HOST = fth-exa-scan.mc.local  )(PORT = 1521)))(CONNECT_DATA = (SERVER = DEDICATED)(SERVICE_NAME =  com4te.mc.local)))"
tbidb <- ROracle::dbConnect(
  dbDriver("Oracle"),
  dbname = connect.string,
  username = "mts_planning_data",
  # mts_planning_view for viewing data only, no write privileges.
  # mts_planning_data is the username for write privileges.
  password = keyring::key_get("mts_planning_data_pw")
)

# Configure database time zone -------------------------------
Sys.setenv(TZ = "America/Chicago")
Sys.setenv(ORA_SDTZ = "America/Chicago")

## Load Detector Configuration -----
#### at the sensor (detector) level (most specific) ----
sensor_config <- read.csv("./data-raw/Configuration of Metro Detectors 2020-03-24.csv") %>%
  filter(
    r_node_n_type != "Intersection",
    r_node_n_type != ""
  ) %>%
  mutate(
    corridor_route = stringr::str_replace(stringr::str_replace(stringr::str_replace(stringr::str_replace(corridor_route, "\\.", " "), "\\.", " "), "T H", "TH"), "U S", "US"),
    # scl_volume = scale(predicted_volume, center = F),
    node_type = case_when(
      r_node_n_type == "Station" ~ "Freeway Segment",
      TRUE ~ r_node_n_type
    )
  ) %>%
  select(-date) # download date of configuration file

#### at the node level (several sensors per node) ----
node_config <-
  sensor_config %>%
  select(
    # get rid of detector-level data:
    -detector_name,
    -detector_label,
    -detector_category,
    -detector_lane,
    -detector_field,
    -detector_abandoned,
    # extraneous data about the nodes:
    -r_node_lanes,
    -r_node_shift,
    -r_node_attach_side
  ) %>%
  # now just get the nodes.
  unique()

#### spatial file for corridors ----
corridors <- nodes %>%
  # this is an object in the package formatted by data-raw/nodes.R
  group_by(corridor_route) %>%
  arrange(r_node_name) %>%
  summarize(do_union = T) %>%
  st_cast("LINESTRING")

## Daily Data: By Node -----
raw_predicted_actual_by_node <-
  ROracle::dbReadTable(tbidb, "RTMC_DAILY_NODE_DIFF_NOW")

predicted_actual_by_node <- raw_predicted_actual_by_node %>%
  rename(
    "r_node_name" = "NODE_NAME",
    "date" = "DATA_DATE",
    "actual_volume" = "TOTAL_VOLUME",
    "predicted_volume" = "VOLUME_PREDICT",
    "volume_difference_absolute" = "VOLUME_DIFF"
  ) %>%
  mutate(date := as.Date(date),
    r_node_id = stringr::str_remove_all(r_node_name, "rnd_")
  ) %>%
  mutate(volume_difference_percent = (volume_difference_absolute / predicted_volume) * 100) %>%
  left_join(node_config) %>%
  filter(
    r_node_n_type != "Intersection",
    r_node_n_type != "",
    date >= "2020-03-01"
  ) %>%
  mutate(
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
      r_node_label,
      " (Node ",
      r_node_id,
      ")",
      "<br>",
      round(volume_difference_percent),
      "%"
    ),
    District = "MnDOT Metro Freeways",
    month_year = format(date, "%B %Y")
  )


unique_corridors <- unique(predicted_actual_by_node$corridor_route)

predicted_actual_by_node <- predicted_actual_by_node %>%
  filter(node_type != "") %>%
  group_by(node_type) %>%
  dplyr::group_split(.keep = TRUE)

names(predicted_actual_by_node) <-
  c("Entrance", "Exit", "Freeway_Segment")

usethis::use_data(predicted_actual_by_node,
  overwrite = TRUE,
  compress = "xz", internal = FALSE
)

usethis::use_data(unique_corridors,
  overwrite = TRUE,
  compress = "xz", internal = FALSE
)


## Daily Data: Entire Region -----
predicted_actual_by_region <-
  ROracle::dbReadTable(tbidb, "RTMC_DAILY_SYSTEM_DIFF_NOW") %>%
  rename(
    "date" = "DATA_DATE",
    "actual_volume" = "TOTAL_VOLUME",
    "predicted_volume" = "TOTAL_PREDICTED_VOLUME",
    "volume_difference_absolute" = "TOTAL_VOLUME_DIFF"
  ) %>%
  mutate(
    volume_difference_percent =
      round(100 * volume_difference_absolute / predicted_volume, 2)
  ) %>%
  mutate(
    District = "MnDOT Metro Freeways",
    weekday = format.Date(date, "%A")
  ) %>%
  arrange(date) %>%
  mutate(
    roll_avg = zoo::rollmean(volume_difference_percent, k = 7, fill = NA),
    month_year = format(date, "%B %Y"),
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



## Daily Data: MnDOT Traffic Trends -----
# we don't really use this anymore -- keeping this open just in case.
predicted_actual_by_state <-
  fread(paste0("./data-raw/diff-vol-state.csv")) %>%
  mutate(volume_percent_difference = `Difference from Typical VMT (%)`) %>%
  select(-`Difference from Typical VMT (%)`) %>%
  mutate(
    date = as.IDate(date),
    District = "MnDOT Statewide",
    month_year = format(date, "%B %Y")
  ) %>%
  arrange(date) %>%
  mutate(
    roll_avg = zoo::rollmean(volume_percent_difference, k = 7, fill = NA),
    hover_text_roll_avg = paste(
      sep = "",
      "<b>",
      format.Date(date, "%A, %B %d, %Y"),
      "</b>",
      "<br>",
      "statewide 7-day average ",
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
      round(volume_percent_difference, digits = 1),
      "%"
    )
  )

# predicted_actual_by_state <- fread(paste0(
#       "https://mn.gov/covid19/assets/StateofMNResponseDashboardCSV_tcm1148-427143.csv"
#     )) %>%
#   janitor::clean_names() %>%
#   filter(covid_team == "Social Distancing",
#          geographic_level == "State") %>%
#   select(data_date_mm_dd_yyyy, value_number) %>%
#   mutate(District = "MnDOT Statewide",
#          date = as.IDate(data_date_mm_dd_yyyy, "%m/%d/%Y"),
#          volume_percent_difference = as.numeric(value_number) * 100,
#          hover_text = paste(
#            sep = "", "<b>", format.Date(date, "%A, %B %d"), "</b>", "<br>",
#            volume_percent_difference, "%"
#          )) %>%
#   select(District, date, volume_percent_difference, hover_text)


usethis::use_data(predicted_actual_by_state,
  overwrite = TRUE,
  compress = "xz", internal = FALSE
)

## Hourly Data: By Node -----
# this data aggregates at the monthly level instead of daily level to keep file size reasonable
hr_node_diff <-
  ROracle::dbGetQuery(tbidb, "SELECT * FROM RTMC_HOURLY_NODE_DIFF_MON_NOW") %>%
  rename(
    "r_node_name" = "NODE_NAME",
    "year" = "DATA_YEAR",
    "month" = "DATA_MONTH",
    "hour" = "DATA_HOUR",
    "actual_volume" = "TOTAL_VOLUME",
    "predicted_volume" = "VOLUME_PREDICT"
  ) %>%
  left_join(node_config, by = c("r_node_name" = "r_node_name")) %>%
  mutate(month_year = paste(month.name[month], year))


hr_node_diff <- left_join(hr_node_diff, nodes)

predicted_actual_node_day_part <- hr_node_diff %>%
  mutate(
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
    day_type = "Weekday",
    r_node_id = stringr::str_remove_all(r_node_name, "rnd_")
  ) %>%
  filter(
    r_node_n_type != "Intersection",
    r_node_n_type != ""
  ) %>%
  group_by(
    day_part, day_type, day_part_short, month_year,
    r_node_lat, r_node_lon,
    r_node_name, r_node_id, r_node_n_type, r_node_label, corridor_route
  ) %>%
  summarize(across(c(actual_volume, predicted_volume), sum)) %>%
  ungroup() %>%
  group_by(day_part, r_node_name) %>%
  mutate(
    rollmean_sum = shift(frollapply(actual_volume, 7, mean, align = "right")),
    rollmean_pred = shift(frollapply(predicted_volume, 7, mean, align = "right"))
  ) %>%
  mutate(
    rollmean_percent = rollmean_sum / rollmean_pred,
    volume_percent_difference = (actual_volume - predicted_volume) / predicted_volume
  ) %>%
  filter(
    # !is.na(rollmean_percent),
    !is.na(day_part),
    day_type == "Weekday"
  ) %>%
  mutate(
    node_type = case_when(
      r_node_n_type == "Station" ~ "Freeway Segment",
      TRUE ~ r_node_n_type
    ),
    user_month_year = factor(month_year,
      levels = c(
        
        ## 2020
        "January 2020",
        "February 2020",
        "March 2020",
        "April 2020",
        "May 2020",
        "June 2020",
        "July 2020",
        "August 2020",
        "September 2020",
        "October 2020",
        "November 2020",
        "December 2020",
        
        ## 2021
        "January 2021",
        "February 2021",
        "March 2021",
        "April 2021",
        "May 2021",
        "June 2021",
        "July 2021",
        "August 2021",
        "September 2021",
        "October 2021",
        "November 2021",
        "December 2021",
        
        "January 2022",
        "February 2022",
        "March 2022",
        "April 2022",
        "May 2022",
        "June 2022",
        "July 2022",
        "August 2022",
        "September 2022",
        "October 2022",
        "November 2022",
        "December 2022"
      ),
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
      r_node_label,
      " (Node ",
      r_node_id,
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
  mutate(
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
  group_by(day_part, day_type, day_part_short, month_year, year, corridor_route) %>%
  summarize(across(c(actual_volume, predicted_volume), sum)) %>%
  ungroup() %>%
  group_by(day_part, corridor_route) %>%
  mutate(
    rollmean_sum = shift(frollapply(actual_volume, 7, mean, align = "right")),
    rollmean_pred = shift(frollapply(predicted_volume, 7, mean, align = "right"))
  ) %>%
  mutate(
    rollmean_percent = rollmean_sum / rollmean_pred,
    volume_percent_difference = (actual_volume - predicted_volume) / predicted_volume
  ) %>%
  filter(
    # !is.na(rollmean_percent),
    !is.na(day_part),
    day_type == "Weekday"
  ) %>%
  mutate(
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
  filter(r_node_n_type == "Station") %>%
  mutate(
    # day_part = case_when(
    #   hour >= 7 & hour <= 9 ~ "Morning, 7-9AM",
    #   hour >= 11 & hour <= 13 ~ "Midday, 11AM-1PM",
    #   hour >= 16 & hour <= 18 ~ "Evening, 4-6PM"
    # ) %>%
    #   factor(levels = c("Morning, 7-9AM", "Midday, 11AM-1PM", "Evening, 4-6PM")),
    # day_part_short = case_when(
    #   hour >= 7 & hour <= 9 ~ "morning",
    #   hour >= 11 & hour <= 13 ~ "midday",
    #   hour >= 16 & hour <= 18 ~ "evening"
    # ),
    # year = "2021",
    month_year = paste(month.name[month], year),
    day_type = "Weekday"
  ) %>%
  group_by(hour, day_type, month_year, year, corridor_route) %>%
  summarize(across(c(actual_volume, predicted_volume), sum)) %>%
  ungroup() %>%
  # group_by(hour, corridor_route) %>%
  # mutate(
  #   rollmean_sum = shift(frollapply(actual_volume, 7, mean, align = "right")),
  #   rollmean_pred = shift(frollapply(predicted_volume, 7, mean, align = "right"))
  # ) %>%
  mutate(
    # rollmean_percent = rollmean_sum / rollmean_pred,
    volume_percent_difference = (actual_volume - predicted_volume) / predicted_volume
  ) %>%
  filter(
    # !is.na(rollmean_percent),
    day_type == "Weekday"
  ) %>%
  mutate(
    user_month_year = factor(month_year,
      levels = c(

        ## 2020
        "January 2020",
        "February 2020",
        "March 2020",
        "April 2020",
        "May 2020",
        "June 2020",
        "July 2020",
        "August 2020",
        "September 2020",
        "October 2020",
        "November 2020",
        "December 2020",

        ## 2021
        "January 2021",
        "February 2021",
        "March 2021",
        "April 2021",
        "May 2021",
        "June 2021",
        "July 2021",
        "August 2021",
        "September 2021",
        "October 2021",
        "November 2021",
        "December 2021",
        
        "January 2022",
        "February 2022",
        "March 2022",
        "April 2022",
        "May 2022",
        "June 2022",
        "July 2022",
        "August 2022",
        "September 2022",
        "October 2022",
        "November 2022",
        "December 2022"
      ),
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
  as.data.table()

usethis::use_data(predicted_actual_corridor_hour,
  overwrite = TRUE,
  compress = "xz", internal = FALSE
)

# diagnostic plot
predicted_actual_corridor_hour %>%
  filter(corridor_route == "TH 61") %>%
  ggplot(aes(x = hour)) +
  geom_line(aes(y = actual_volume), color = "blue") +
  geom_line(aes(y = predicted_volume), color = "black") +
  facet_wrap(~user_month_year) +
  theme_void() +
  theme(panel.grid = element_blank())


# Hourly Data, Entire System -----
hr_system_diffs <- ROracle::dbReadTable(tbidb, "RTMC_HOURLY_SYSTEM_DIFF_NOW") %>%
  rename(
    "date" = "DATA_DATE",
    "hour" = "DATA_HOUR",
    "actual_volume" = "TOTAL_VOLUME",
    "predicted_volume"  = "TOTAL_PREDICTED_VOLUME",
    "volume_difference_absolute" = "TOTAL_VOLUME_DIFF"
  ) %>%
  mutate(date = as.Date(date)) %>%
  mutate(dow = lubridate::wday(date, label = T, abbr = F))

#### Aggregated to Day part -----
predicted_actual_by_region_day_part <- hr_system_diffs %>%
  mutate(
    volume_percent_difference = (volume_difference_absolute / predicted_volume) * 100,
    date = lubridate::ymd(date),
    month_year = month.name[lubridate::month(date)],
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
    District = "MnDOT Metro Freeways",
    weekday = format.Date(date, "%A"),
    day_type = case_when(
      weekday %in% c("Saturday", "Sunday") ~ "Weekend",
      TRUE ~ "Weekday"
    )
  ) %>%
  filter(
    !is.na(day_part),
    day_type == "Weekday"
  ) %>%
  group_by(date, dow, day_part, day_part_short, District) %>%
  # add up the volume:
  summarize(
    actual_volume = sum(actual_volume),
    predicted_volume = sum(predicted_volume),
    volume_difference_absolute = sum(volume_difference_absolute)
  ) %>%
  ungroup() %>%
  arrange(date) %>%
  group_by(day_part) %>%
  mutate(
    roll_avg_predicted = zoo::rollmean(predicted_volume, k = 7, fill = NA),
    roll_avg_observed = zoo::rollmean(actual_volume, k = 7, fill = NA),
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
showtext::showtext.auto()
static_plot <-
  ggplot() +
  theme_minimal() +
  geom_line(
    data = predicted_actual_by_region,
    aes(
      x = date,
      y = roll_avg,
      color = "7-Day Rolling Average"
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
  scale_x_datetime(
    limits = c(
      as.POSIXct("2020-01-03"),
      max(predicted_actual_by_region$date)
    ),
    date_breaks = "2 months",
    date_labels = "%b %Y"
  ) +
  labs(
    y = "% difference from typical traffic",
    x = "",
    color = "",
    title = "Change in MnDOT Metro Freeway Traffic",
    subtitle = "Daily relative difference in observed versus expected freeway traffic",
    caption = paste0("Last updated ", max(predicted_actual_by_region$date))
  ) +
  annotate(
    geom = "rect",
    xmin = as.POSIXct("2020-03-27"),
    xmax = as.POSIXct("2020-05-18"),
    ymin = -Inf,
    ymax = Inf,
    fill = councilR::colors$suppGray,
    alpha = 0.2
  ) +
  councilR::council_theme(
    use_showtext = T,
    size_axis_text = 10,
    size_header = 16
  ) +
  theme(
    panel.grid.minor.y = element_blank(),
    plot.background = element_rect(
      fill = "white",
      linetype = "blank"
    ),
    # panel.grid.major.y = element_blank(),
    legend.position = "bottom",
    plot.title.position = "plot"
  ) + 
  theme(axis.title.x  = element_text(size = 40),
        axis.title.y  = element_text(size = 40),
        axis.text.x = element_text(size = 28),
        axis.text.y = element_text(size = 32),
        plot.caption = element_text(size = 36),
        plot.title = element_text(size = 72),
        plot.subtitle = element_text(size = 36),
        legend.text = element_text(size = 36))

static_plot


ggsave("inst/app/www/predicted_actual_plot.png",
  static_plot,
  height = 5.5, width = 7.5, units = "in"
)

## covid plot only -----
covid_plot <- ggplot() +
  theme_minimal() +
  geom_line(
    data = predicted_actual_by_region,
    aes(
      x = date,
      y = roll_avg,
      color = "MnDOT Metro Freeways\n7-Day Rolling Average\n"
    )
  ) +
  geom_line(
    data = predicted_actual_by_state,
    aes(
      x = date %>%
        as.POSIXct(),
      y = roll_avg,
      color = "MnDOT Statewide\n7-Day Rolling Average"
    )
  ) +
  geom_point(
    data = predicted_actual_by_region,
    aes(
      x = date,
      y = volume_difference_percent,
      color = "MnDOT Metro Freeway\nDaily Difference"
    ),
    # color = councilR::colors$councilBlue,
    size = 1.1,
    shape = 16,
    alpha = 0.6
  ) +
  geom_point(
    data = predicted_actual_by_state,
    aes(
      x = date %>% as.POSIXct(),
      y = volume_percent_difference,
      color = "MnDOT Statewide \nDaily Difference"
    ),
    size = 1.1,
    shape = 16,
    alpha = 0.6
  ) +
  geom_hline(yintercept = 0) +
  scale_color_manual(
    guide = guide_legend(
      title = "Traffic Sensor Group",
      override.aes = list(
        linetype = c("blank", "solid", "blank", "solid"),
        shape = c(16, NA, 16, NA),
        size = c(2, 1, 2, 1)
      )
    ),
    values = c(
      councilR::colors$councilBlue,
      councilR::colors$councilBlue,
      "black",
      "black"
    )
  ) +
  scale_y_continuous(
    limits = c(-70, 10),
    breaks = seq(10, -70, by = -10),
    labels = scales::label_comma(suffix = "%")
  ) +
  scale_x_datetime(
    limits = c(
      as.POSIXct("2020-03-01"),
      as.POSIXct("2021-03-01")
    ),
    date_breaks = "2 month",
    date_labels = "%b %Y"
  ) +
  labs(
    y = "% difference from typical traffic",
    x = "",
    color = "",
    # title = "COVID-19 Affects on Traffic Volumes",
    title = "Change in traffic volume, March 2020 to March 2021",
    caption = paste0("Last updated ", Sys.Date())
  ) +
  annotate(
    geom = "rect",
    xmin = as.POSIXct("2020-03-27"),
    xmax = as.POSIXct("2020-05-18"),
    ymin = -Inf,
    ymax = Inf,
    fill = councilR::colors$suppGray,
    alpha = 0.2
  ) +
  councilR::council_theme(
    use_showtext = T,
    size_axis_text = 8,
    size_legend_title = 10,
    size_header = 14,
    size_legend_text = 8,
    size_margin = 10,
    size_caption = 6,
    size_axis_title = 10
  ) +
  theme(
    panel.grid.minor.y = element_blank(),
    plot.background = element_rect(
      fill = "white",
      linetype = "blank"
    ),
    # panel.grid.major.y = element_blank(),
    plot.title.position = "plot",
    plot.caption.position = "plot"
    # legend.box.margin = margin(rep(0, 4), "pt"),
    # legend.text = element_text(
    #   lineheight = 1.1,
    #   margin = unit(rep(c(2, 0), 2), "pt")
    # )
  ) + 
  theme(axis.title.x  = element_text(size = 40),
        axis.title.y  = element_text(size = 40),
        axis.text.x = element_text(size = 28),
        axis.text.y = element_text(size = 32),
        plot.caption = element_text(size = 36),
        plot.title = element_text(size = 72),
        plot.subtitle = element_text(size = 36),
        legend.text = element_text(size = 16),
        legend.title = element_text(size = 18))

covid_plot

ggsave("inst/app/www/covid_plot.png",
  covid_plot,
  height = 4, width = 7.5, units = "in"
)