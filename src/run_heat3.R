library(sf) # st_read
library(data.table) # fread
source("../R/heat3.R")

#################
### Arguments ###
#################

args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_relevantStationSamplesPath = args[1]
in_unitsCleanedFilePath = args[2]
in_configurationFilePath = args[3]
combined_Chlorophylla_IsWeighted = args[4]
out_AnnualIndicatorPath = args[5]
verbose = args[6]
veryverbose = args[7]

## Verbosity
if (is.na(verbose)) {
    verbose <- TRUE
} else if (tolower(verbose) == "false") {
    verbose <- FALSE
} else {
    verbose <- TRUE
}
if (is.na(veryverbose)) {
    veryverbose <- FALSE
} else if (tolower(veryverbose) == "true") {
    veryverbose <- TRUE
} else {
    veryverbose <- FALSE
}

# Flag to determine if the combined chlorophyll a in-situ/satellite indicator is
# a simple mean or a weighted mean based on confidence measures
if (tolower(combined_Chlorophylla_IsWeighted) == 'true') {
  combined_Chlorophylla_IsWeighted <- TRUE
} else {
  combined_Chlorophylla_IsWeighted <- FALSE
}
if (verbose) message(paste('combined_Chlorophylla_IsWeighted:', combined_Chlorophylla_IsWeighted))


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


####################
### Computing... ###
####################

if (verbose) message("Looping over the indicators  (and some more)...")
wk3 <- compute_annual_indicators(stationSamples, units, in_configurationFilePath, combined_Chlorophylla_IsWeighted, verbose, veryverbose)
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
