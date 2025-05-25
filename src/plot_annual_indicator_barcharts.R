source("../R/all_heat_functions.R")
source("../R/heat_plot_functions.R")

#################
### Arguments ###
#################

args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
assessmentPeriod = args[1]
in_wk3_path = args[2] # Annual_Indicator.csv
in_unitsFilePath = args[3]
in_configIndicatorsFilePath = args[4]
out_plotsPath = args[5]
verbose = args[6]

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

if (verbose) message(paste('Reading input table from', in_wk3_path, '...'))
wk3 = data.table::fread(file=in_wk3_path)
if (verbose) message(paste('Reading input units from', in_unitsFilePath, '...'))
units <- get_units(assessmentPeriod, in_unitsFilePath, verbose)
if (verbose) message(paste('Reading input indicators from', in_configIndicatorsFilePath, '...'))
indicators <- get_indicators_table(in_configIndicatorsFilePath, format="xlsx")


###################
### Plotting... ###
###################

# Assessment indicator maps
if (verbose) message("Create Assessment Indicator maps...")
plot_annual_indicator_barcharts(wk3, units, indicators, out_plotsPath, verbose)
if (verbose) message("Create Assessment Indicator maps... DONE.")
message('R script finished running.')
