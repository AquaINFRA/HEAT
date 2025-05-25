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


###################
### Read inputs ###
###################

if (verbose) message(paste('Reading input table from', in_wk9_path, '...'))
wk9 = data.table::fread(file=in_wk9_path)
if (verbose) message(paste('Reading input units from', in_unitsFilePath, '...'))
units <- get_units(assessmentPeriod, in_unitsFilePath, verbose)

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
