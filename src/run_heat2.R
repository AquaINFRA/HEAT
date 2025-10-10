library(sf) # st_read
source("../R/all_heat_functions.R")
source("../src/utils_download.R")


#################
### Arguments ###
#################

args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_stationSamplesBOTFilePathOrUrl = args[1]
in_stationSamplesCTDFilePathOrUrl = args[2]
in_stationSamplesPMPFilePathOrUrl = args[3]
in_unitsGriddedPathOrUrl = args[4]
out_stationSamplesBOTFilePath = args[5]
out_stationSamplesCTDFilePath = args[6]
out_stationSamplesPMPFilePath = args[7]
out_stationSamplesTableCSVFilePath = args[8]
input_dir = args[9]
verbose = args[10]

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

## If users pass "null" for a file:
if (in_stationSamplesBOTFilePathOrUrl == 'null') in_stationSamplesBOTFilePathOrUrl <- NA
if (in_stationSamplesCTDFilePathOrUrl == 'null') in_stationSamplesCTDFilePathOrUrl <- NA
if (in_stationSamplesPMPFilePathOrUrl == 'null') in_stationSamplesPMPFilePathOrUrl <- NA


#######################
### Download inputs ###
#######################

# Gridded spatial units (zipped shapefile)
if (startsWith(in_unitsGriddedPathOrUrl, 'http')) {
  message("DEBUG: Shapefile provided as URL: ", in_unitsGriddedPathOrUrl)
  targetpath = paste0(input_dir, "/griddedUnits.zip")
  in_unitsGriddedFilePath <- download_unzip_shapefile(in_unitsGriddedPathOrUrl, targetpath)
} else {
  message("DEBUG: Shapefile provided as path: ", in_unitsGriddedPathOrUrl)
  in_unitsGriddedFilePath <- in_unitsGriddedPathOrUrl
}


# Download tabular data (3 files):

if (is.na(in_stationSamplesBOTFilePathOrUrl)) {
  in_stationSamplesBOTFilePath <- NA # passing NA is allowed
  message("DEBUG: No BOT data provided, using NA...")
} else if (startsWith(in_stationSamplesBOTFilePathOrUrl, 'http')) {
  message("DEBUG: BOT data provided as URL: ", in_stationSamplesBOTFilePathOrUrl)
  targetpath = paste0(input_dir, "/downloaded_bot_data")
  in_stationSamplesBOTFilePath <- download_maybe_unzip(in_stationSamplesBOTFilePathOrUrl, targetpath)
} else {
  message("DEBUG: BOT data provided as path: ", in_stationSamplesBOTFilePathOrUrl)
  in_stationSamplesBOTFilePath <- in_stationSamplesBOTFilePathOrUrl
}

if (is.na(in_stationSamplesCTDFilePathOrUrl)) {
  in_stationSamplesCTDFilePath <- NA # passing NA is allowed
  message("DEBUG: No CTD data provided, using NA...")
} else if (startsWith(in_stationSamplesCTDFilePathOrUrl, 'http')) {
  message("DEBUG: CTD data provided as URL: ", in_stationSamplesCTDFilePathOrUrl)
  targetpath = paste0(input_dir, "/downloaded_ctd_data")
  in_stationSamplesCTDFilePath <- download_maybe_unzip(in_stationSamplesCTDFilePathOrUrl, targetpath)
} else {
  message("DEBUG: CTD data provided as path: ", in_stationSamplesCTDFilePathOrUrl)
  in_stationSamplesCTDFilePath <- in_stationSamplesCTDFilePathOrUrl
}

if (is.na(in_stationSamplesPMPFilePathOrUrl)) {
  in_stationSamplesPMPFilePath <- NA # passing NA is allowed
  message("DEBUG: No PMP data provided, using NA...")
} else if (startsWith(in_stationSamplesPMPFilePathOrUrl, 'http')) {
  message("DEBUG: PMP data provided as URL: ", in_stationSamplesPMPFilePathOrUrl)
  targetpath = paste0(input_dir, "/downloaded_pmp_data")
  in_stationSamplesPMPFilePath <- download_maybe_unzip(in_stationSamplesPMPFilePathOrUrl, targetpath)
} else {
  message("DEBUG: PMP data provided as path: ", in_stationSamplesPMPFilePathOrUrl)
  in_stationSamplesPMPFilePath <- in_stationSamplesPMPFilePathOrUrl
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
