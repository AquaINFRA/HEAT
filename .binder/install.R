print("install.R: Start...")

# Define required packages.
required_packages_versions <- list(
  "sf" = "1.0-20",
  "data.table" = "1.17.0",
  "tidyverse" = "2.0.0",
  "readxl" = "1.4.5",
  "R.utils" = "2.13.0"
)

if (!requireNamespace("remotes", quietly = TRUE)) {
  install.packages("remotes", repos = "https://cran.rstudio.com/")
}

# Define function to install from CRAN.
install_if_missing <- function(pkg, version) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    remotes::install_version(pkg, version = version, repos = "https://cran.rstudio.com/")
  }
}

# Logging:
num = length(required_packages_versions)
list_dep = paste(names(required_packages_versions), collapse=" + ")
print(paste0("install.R: Install ", num, " dependencies: ", list_dep, "..."))

# Run the installs:
invisible(lapply(names(required_packages_versions), function(pkg) {
  install_if_missing(pkg, required_packages_versions[[pkg]])
}))

# Session info:
print("install.R: sessionInfo...")
sessionInfo()
