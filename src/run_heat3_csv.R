library(sf) # st_read
library(data.table) # fread
source("../R/all_heat_functions.R")
source("../src/utils_download.R")


#################
### Arguments ###
#################

args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_relevantStationSamplesPathOrUrl = args[1]
in_unitsCleanedFilePathOrUrl = args[2]
in_configIndicatorsFilePath = args[3]
in_configIndicatorUnitsFilePath = args[4]
in_configIndicatorUnitResultsFilePath = args[5]
combined_Chlorophylla_IsWeighted = args[6]
out_AnnualIndicatorPath = args[7]
input_dir = args[8]
verbose = args[9]

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

# Flag to determine if the combined chlorophyll a in-situ/satellite indicator is
# a simple mean or a weighted mean based on confidence measures
if (tolower(combined_Chlorophylla_IsWeighted) == 'true') {
  combined_Chlorophylla_IsWeighted <- TRUE
} else {
  combined_Chlorophylla_IsWeighted <- FALSE
}
if (verbose) message(paste('combined_Chlorophylla_IsWeighted:', combined_Chlorophylla_IsWeighted))


#######################
### Download inputs ###
#######################

# Cleaned spatial units (zipped shapefile)
if (startsWith(in_unitsCleanedFilePathOrUrl, 'http')) {
  message("DEBUG: Shapefile provided as URL: ", in_unitsCleanedFilePathOrUrl)
  targetpath = paste0(input_dir, "/cleanedUnits.zip")
  in_unitsCleanedFilePath <- download_unzip_shapefile(in_unitsCleanedFilePathOrUrl, targetpath)
} else {
  message("DEBUG: Shapefile provided as path: ", in_unitsCleanedFilePathOrUrl)
  in_unitsCleanedFilePath <- in_unitsCleanedFilePathOrUrl
}

# Download tabular data
if (is.na(in_relevantStationSamplesPathOrUrl)) {
  in_relevantStationSamplesPath <- NA # passing NAs is allowed!
} else if (startsWith(in_relevantStationSamplesPathOrUrl, 'http')) {
  targetpath = paste0(input_dir, "/stationSamples")
  in_relevantStationSamplesPath <- download_maybe_unzip(in_relevantStationSamplesPathOrUrl, targetpath)
} else {
  in_relevantStationSamplesPath <- in_relevantStationSamplesPathOrUrl
}

###################
### Read inputs ###
###################

# Load required intermediate file:
if (verbose) message(paste('Reading station samples from:', in_relevantStationSamplesPath, '...'))
stationSamples <- data.table::fread(in_relevantStationSamplesPath)
if (verbose) message(paste('Reading station samples from:', in_relevantStationSamplesPath, '... DONE.'))
if (verbose) message(paste('Reading cleaned units from:', in_unitsCleanedFilePath, '...'))
units <- sf::st_read(in_unitsCleanedFilePath)
if (verbose) message(paste('Reading cleaned units from:', in_unitsCleanedFilePath, '... DONE.'))

# Correct column name:
if (! "UnitArea" %in% names(units)) {
  if ("UnitAre" %in% names(units)) {
    colnames(units)[colnames(units)=="UnitAre"] <- "UnitArea"
  } else {
    message('Missing column UnitArea or UnitAre in units...')
    stop('Missing column UnitArea or UnitAre in units...')
  }
}

# Read indicator configs -------------------------------------------------------
indicators <- get_indicators_table(in_configIndicatorsFilePath, format="csv")
indicatorUnits <- get_indicator_units_table(in_configIndicatorUnitsFilePath, format="csv")
indicatorUnitResults <- get_indicator_unit_results_table(in_configIndicatorUnitResultsFilePath, format="csv")


####################
### Computing... ###
####################

if (verbose) message("Looping over the indicators  (and some more)...")
wk3 <- compute_annual_indicators(stationSamples, units, indicators, indicatorUnits, indicatorUnitResults, combined_Chlorophylla_IsWeighted, verbose)
if (verbose) message("Looping over the indicators  (and some more)... DONE.")
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
if (file.exists(out_AnnualIndicatorPath) && !overwrite) {
    stop(paste0("Output already exists, cannot overwrite (", out_AnnualIndicatorPath,")"))
}

# Create directory if not exists 
if (!file.exists(dirname(out_AnnualIndicatorPath))) {
    dir.create(dirname(out_AnnualIndicatorPath), showWarnings = FALSE, recursive = TRUE)
}

# Actual storing:
if (verbose) message("Storing results...")
data.table::fwrite(wk3, file = out_AnnualIndicatorPath)
if (verbose) message(paste('Stored result:', out_AnnualIndicatorPath))
if (verbose) message("Storing results... DONE.")
message('R script finished running.')
