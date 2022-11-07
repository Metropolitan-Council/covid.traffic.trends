#' Deploy apps on shinyapps.io
#'
#' @param app_dir Shiny app directory. Default is the current working directory.
#' @return No return value
#' 
#' @note If this function fails due to councilR access, try installing councilR 
#'     using `remotes::install_github("Metropolitan-Council/councilR", force = TRUE)`.
#' @export
#' @keywords internal
#' @noRd
#'
deploy_app <- function(app_dir = getwd()) {


  # deploy to freeway-traffic-trends
  rsconnect::deployApp(
    appDir = app_dir,
    account = "metrotransitmn",
    server = "shinyapps.io",
    appName = "freeway-traffic-trends",
    appId = 4453531,
    launch.browser = function(url) {
      message("Deployment completed: ", url)
    },
    lint = FALSE,
    metadata = list(
      asMultiple = FALSE,
      asStatic = FALSE,
      ignoredFiles = "dev/01_start.R|dev/02_dev.R|dev/03_deploy.R|dev/run_dev.R|LICENSE|LICENSE.md|man/run_app.Rd|README.md|README.Rmd|tests/testthat/test-app.R|tests/testthat/test-golem-recommended.R|tests/testthat.R|vignettes/potential_streetlight_analyses.Rmd"
    ),
    logLevel = "verbose",
    forceUpdate = TRUE
  )

  # wait for 20 seconds
  Sys.sleep(20)


  # deploy to covid-traffic-trends
  rsconnect::deployApp(
    appDir = app_dir,
    account = "metrotransitmn",
    server = "shinyapps.io",
    appName = "covid-traffic-trends",
    appId = 2004244,
    launch.browser = function(url) {
      message("Deployment completed: ", url)
    },
    lint = FALSE,
    metadata = list(
      asMultiple = FALSE,
      asStatic = FALSE,
      ignoredFiles = "dev/01_start.R|dev/02_dev.R|dev/03_deploy.R|dev/run_dev.R|LICENSE|LICENSE.md|man/run_app.Rd|README.md|README.Rmd|tests/testthat/test-app.R|tests/testthat/test-golem-recommended.R|tests/testthat.R|vignettes/potential_streetlight_analyses.Rmd"
    ),
    logLevel = "verbose",
    forceUpdate = TRUE
  )

  usethis::ui_done("Both apps deployed!")
}
