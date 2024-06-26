# Set options here
options(
  shiny.launch.browser = TRUE,
  scipen = 9999,
  warn = -1,
  verbose = FALSE,
  golem.app.prod = FALSE
) # TRUE = production mode, FALSE = development mode

# Detach all loaded packages and clean your environment
# golem::detach_all_attached()
# rm(list=ls(all.names = TRUE))
# remove.packages("council.skeleton", lib="~/R/win-library/3.6")
# remotes::install_github("Metropolitan-Council/council.skeleton", upgrade = "never")

rmarkdown::render("./ABOUT.Rmd",
  output_format = "github_document", # -----
  output_file = "ABOUT.md", output_dir = "./inst/app/www",
  params = list(
    actor_id = "roten",
    data_date = Sys.Date(),
    sha = system("git rev-parse --short HEAD",
      intern = TRUE
    )
  )
)


# Document and reload your package ----
golem::document_and_reload()

# Run the application
run_app()

