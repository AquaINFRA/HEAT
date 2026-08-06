source("../R/all_heat_functions.R")
source("../R/heat_plot_functions.R")

#################
### Arguments ###
#################

args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
assessmentPeriod = args[1]
in_wk9_path = args[2] # Assessment.csv
in_unitsFilePath = args[3]
out_plotsPath = args[4]
verbose = args[5]

## Verbosity
if (is.na(verbose)) {
    verbose <- TRUE
} else if (tolower(verbose) == "false") {
    verbose <- FALSE
} else {
    verbose <- TRUE
}

## Convert to proper null, in case you do not want to set the assessment period:
# TODO: To be tested! (Not sure this script was ever meant for running without the assessment period.)
# Note: If assessmentPeriod is NULL, then generic=FALSE is ignored in get_units()
if (tolower(assessmentPeriod)=="null") {
    assessmentPeriod <- NULL
}


###################
### Read inputs ###
###################

if (verbose) message(paste('Reading input table from', in_wk9_path, '...'))
wk9 = data.table::fread(file=in_wk9_path)
if (verbose) message(paste('Reading input units from', in_unitsFilePath, '...'))
units <- get_units(assessmentPeriod, in_unitsFilePath, verbose, generic=FALSE)

###################
### Plotting... ###
###################

if (verbose) message("Prepare plots...")
EQRS_Classes <- get_EQRS_colors()
C_Classes <- get_C_colors()

# Status maps
if (verbose) message("Create status maps...")
plot_status_maps(wk9, units, assessmentPeriod, EQRS_Classes, C_Classes, out_plotsPath, verbose)
if (verbose) message("Create status maps... DONE.")
message('R script finished running.')
