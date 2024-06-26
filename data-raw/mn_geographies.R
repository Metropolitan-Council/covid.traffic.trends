# code for developing Minnesota geographies here

pkgload::load_all()
library(covid.traffic.trends)
library(dplyr)
library(sf)
library(tigris)
options(tigris_use_cache = FALSE)

mn_counties <- tigris::counties(
  state = "MN",
  class = "sf"
) %>%
  dplyr::select(NAME) %>%
  sf::st_set_crs(4326)

usethis::use_data(mn_counties, overwrite = TRUE, compress = "xz")


mn_cities <- tigris::places(
  state = "MN",
  class = "sf"
) %>%
  dplyr::select(NAME, NAMELSAD) %>%
  sf::st_set_crs(4326)

usethis::use_data(mn_cities, overwrite = TRUE, compress = "xz")
