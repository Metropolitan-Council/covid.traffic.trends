## code to prepare `table_data` dataset goes here

library(covid.traffic.trends)
library(sf)
library(data.table)
library(dplyr)
## table data


table_data <- rbind(
  predicted_actual_by_region %>%
    mutate(
      weekday = format.Date(date, "%A"),
      `date` = as.character(`date`)
    ) %>%
    select(
      date,
      weekday,
      District,
      actual_volume,
      predicted_volume,
      volume_difference_percent,
      roll_avg
    )
  # mutate(predicted_actual_by_state,
  #   weekday = weekdays(`date`),
  #   vmt.sum = NA,
  #   vmt.predict = NA,
  #   `date` = as.character(`date`)
  # ) %>%
  #   select(
  #     date,
  #     weekday,
  #     District,
  #     actual_volume,
  #     predicted_volume,
  #     volume_difference_percent,
  #     roll_avg
  #   )
) %>%
  filter(District == "MnDOT Metro Freeways")


usethis::use_data(table_data, overwrite = TRUE, compress = "xz")
