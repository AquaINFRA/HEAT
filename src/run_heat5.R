library(data.table) # fread
source("../R/all_heat_functions.R")


#################
### Arguments ###
#################

args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_AssessmentIndicatorPath = args[1]
in_configurationFilePath = args[2]
out_AssessmentPath = args[3]
verbose = args[4]

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

# Load R input data: AssessmentIndicators.csv
# This was HTTP-POSTed by the user, then stored to disk by pygeoapi, and now read by R:
if (verbose) message(paste('Reading input table from', in_AssessmentIndicatorPath, '...'))
wk5 = data.table::fread(file=in_AssessmentIndicatorPath)
if (verbose) message(paste('Reading input table from', in_AssessmentIndicatorPath, '... DONE.'))

# Read indicator configs -------------------------------------------------------
indicators <- get_indicators_table(in_configurationFilePath, format="xlsx")
indicatorUnits <- get_indicator_units_table(in_configurationFilePath, format="xlsx")


####################
### Computing... ###
####################

if (verbose) message("Calculating criteria, assessment...")
wk9 <- compute_assessment(wk5, indicators, indicatorUnits, verbose)
if (verbose) message("Calculating criteria, Assessment... DONE.")
if (verbose) message('Calculation done.')


#####################
### Store results ###
#####################

# Should we overwrite old results?
overwrite <- "true" # not boolean, because if we set this via command line arg it is always string!
if (is.na(overwrite)) {
    overwrite <- FALSE
} else if (tolower(overwrite) == "true") {
    overwrite <- TRUE
} else {
    overwrite <- FALSE
}
if (file.exists(out_AssessmentPath) && !overwrite) {
    stop(paste0("Output already exists, cannot overwrite (", out_AssessmentPath,")"))
}

# Create directory if not exists 
if (!file.exists(dirname(out_AssessmentPath))) {
    dir.create(dirname(out_AssessmentPath), showWarnings = FALSE, recursive = TRUE)
}

# Actual storing:
if (verbose) message("Storing results...")
data.table::fwrite(wk9, file = out_AssessmentPath)
if (verbose) message(paste('Stored result:', out_AssessmentPath))
if (verbose) message("Storing results... DONE.")
message('R script finished running.')

