library(data.table) # fread
source("../R/all_heat_functions.R")
source("../src/utils_download.R")


#################
### Arguments ###
#################

args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
input_dir = args[1]
in_AssessmentIndicatorPathOrUrl = args[2]
in_configIndicatorsFilePathOrUrl = args[3]
in_configIndicatorUnitsFilePathOrUrl = args[4]
out_AssessmentPath = args[5]
verbose = args[6]

## Verbosity
if (is.na(verbose)) {
    verbose <- TRUE
} else if (tolower(verbose) == "false") {
    verbose <- FALSE
} else {
    verbose <- TRUE
}

## Input dir, for data that has to be downloaded:
if (is.na(input_dir)) {
    input_dir = "."
} else if (endsWith(input_dir, '/')) {
    input_dir = sub("/+$", "", input_dir)
}

#######################
### Download inputs ###
#######################

# Download tabular data
if (startsWith(in_AssessmentIndicatorPathOrUrl, 'http')) {
  targetpath = paste0(input_dir, "/assessment_indicators")
  in_AssessmentIndicatorPath <- download_maybe_unzip(in_AssessmentIndicatorPathOrUrl, targetpath)
} else {
  in_AssessmentIndicatorPath <- in_AssessmentIndicatorPathOrUrl
}

# Download config tables:
# (1/3)
if (startsWith(in_configIndicatorsFilePathOrUrl, 'http')) {
  message("DEBUG: Indicators table provided as URL: ", in_configIndicatorsFilePathOrUrl)
  targetpath = paste0(input_dir, "/indicators")
  in_configIndicatorsFilePath <- download_maybe_unzip(in_configIndicatorsFilePathOrUrl, targetpath)
} else {
  message("DEBUG: Indicators table provided as path: ", in_configIndicatorsFilePathOrUrl)
  in_configIndicatorsFilePath <- in_configIndicatorsFilePathOrUrl
}
# (2/3)
if (startsWith(in_configIndicatorUnitsFilePathOrUrl, 'http')) {
  message("DEBUG: Grid size table provided as URL: ", in_configIndicatorUnitsFilePathOrUrl)
  targetpath = paste0(input_dir, "/indicator_units")
  in_configIndicatorUnitsFilePath <- download_maybe_unzip(in_configIndicatorUnitsFilePathOrUrl, targetpath)
} else {
  message("DEBUG: Grid size table provided as path: ", in_configIndicatorUnitsFilePathOrUrl)
  in_configIndicatorUnitsFilePath <- in_configIndicatorUnitsFilePathOrUrl
}


###################
### Read inputs ###
###################

# Load R input data: AssessmentIndicators.csv
if (verbose) message(paste('Reading input table from', in_AssessmentIndicatorPath, '...'))
wk5 = data.table::fread(file=in_AssessmentIndicatorPath)
if (verbose) message(paste('Reading input table from', in_AssessmentIndicatorPath, '... DONE.'))

# Read indicator configs -------------------------------------------------------
indicators <- get_indicators_table(in_configIndicatorsFilePath, format="csv")
indicatorUnits <- get_indicator_units_table(in_configIndicatorUnitsFilePath, format="csv")


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

