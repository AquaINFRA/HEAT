library(sf) # st_read
#library(data.table)
source("../R/heat2_stations.R")

#################
### Arguments ###
#################

args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_stationSamplesBOTFilePath = args[1]
in_stationSamplesCTDFilePath = args[2]
in_stationSamplesPMPFilePath = args[3]
in_unitsGriddedFilePath = args[4]
out_stationSamplesBOTFilePath = args[5]
out_stationSamplesCTDFilePath = args[6]
out_stationSamplesPMPFilePath = args[7]
out_stationSamplesTableCSVFilePath = args[8]
verbose = args[9]

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

## Read gridunits (output of heat1)
if (verbose) message(paste('Reading spatial units from:', in_unitsGriddedFilePath, '...'))
gridunits <- sf::st_read(in_unitsGriddedFilePath)
if (verbose) message(paste('Reading spatial units from:', in_unitsGriddedFilePath, '... DONE.'))


####################
### Computing... ###
####################

## Read station sample data
if (verbose) message("Preparing station samples... (this consumes a lot of memory...)")
stationSamples <- prepare_station_samples(
    in_stationSamplesBOTFilePath,
    in_stationSamplesCTDFilePath,
    in_stationSamplesPMPFilePath,
    gridunits,
    verbose)
if (verbose) message("Preparing station samples... DONE.")
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

# Check if exist, create dirs:
all_out_paths = c(
    out_stationSamplesTableCSVFilePath,
    out_stationSamplesBOTFilePath,
    out_stationSamplesCTDFilePath,
    out_stationSamplesPMPFilePath
)

for (out_path in all_out_paths) {
    if (file.exists(out_path) && !overwrite) {
        stop(paste0("Output already exists, cannot overwrite (", out_path,")"))
    }
    if (!file.exists(dirname(out_path))) {
        dir.create(dirname(out_path), showWarnings = FALSE, recursive = TRUE)
    }
}


# Actual storing:
if (verbose) message("Storing results...")

# Main result:
data.table::fwrite(stationSamples, out_stationSamplesTableCSVFilePath, row.names = TRUE)
if (verbose) message(paste('Stored result:', out_stationSamplesTableCSVFilePath))

# Individual results:
# Output station samples mapped to assessment units for contracting parties to check i.e. acceptance level 1
data.table::fwrite(stationSamples[Type == 'B'], out_stationSamplesBOTFilePath)
if (verbose) message(paste('Stored result:', out_stationSamplesBOTFilePath))
data.table::fwrite(stationSamples[Type == 'C'], out_stationSamplesCTDFilePath)
if (verbose) message(paste('Stored result:', out_stationSamplesCTDFilePath))
data.table::fwrite(stationSamples[Type == 'P'], out_stationSamplesPMPFilePath)
if (verbose) message(paste('Stored result:', out_stationSamplesPMPFilePath))
if (verbose) message("Storing results... DONE.")
message('R script finished running.')
