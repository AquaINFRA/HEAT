library(stringr) # "str_sub"

download_inputs <- function(assessmentPeriod, inputPath, verbose=TRUE) {

  # Remove trailing slash, if applicable
  if (endsWith(inputPath, "/")) {
    inputPath <- str_sub(inputPath, end = -2)
  }

  # Download and unpack files needed for the assessment --------------------------
  if (verbose) message("Download and unpack files needed for the assessment...")
  download.file.unzip.maybe <- function(url, refetch = FALSE, path = ".") {
    dest <- file.path(path, sub("\\?.+", "", basename(url)))
    if (refetch || !file.exists(dest)) {
      download.file(url, dest, mode = "wb")
      if (tools::file_ext(dest) == "zip") {
        unzip(dest, exdir = path)
      }
    }
  }

  # Define empty variables:
  urls <- c()
  unitsFile <- file.path(inputPath, "")
  configurationFile <- file.path(inputPath, "")
  stationSamplesBOTFile <- file.path(inputPath, "")
  stationSamplesCTDFile <- file.path(inputPath, "")
  stationSamplesPMPFile <- file.path(inputPath, "")

  # Define URLs for all required files:
  message(paste("Will download to", inputPath))
  if (assessmentPeriod == "1877-9999"){
    urls <- c("https://icesoceanography.blob.core.windows.net/heat/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022_eutro.zip",
              "https://icesoceanography.blob.core.windows.net/heat/Configuration1877-9999.xlsx",
              "https://icesoceanography.blob.core.windows.net/heat/StationSamples1877-9999BOT_2022-12-09.txt.gz",
              "https://icesoceanography.blob.core.windows.net/heat/StationSamples1877-9999CTD_2022-12-09.txt.gz",
              "https://icesoceanography.blob.core.windows.net/heat/StationSamples1877-9999PMP_2022-12-09.txt.gz")
    unitsFile <- file.path(inputPath, "HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022_eutro.shp")
    configurationFile <- file.path(inputPath, "Configuration1877-9999.xlsx")
    stationSamplesBOTFile <- file.path(inputPath, "StationSamples1877-9999BOT_2022-12-09.txt.gz")
    stationSamplesCTDFile <- file.path(inputPath, "StationSamples1877-9999CTD_2022-12-09.txt.gz")
    stationSamplesPMPFile <- file.path(inputPath, "StationSamples1877-9999PMP_2022-12-09.txt.gz")
  } else if (assessmentPeriod == "2011-2016"){
    urls <- c("https://icesoceanography.blob.core.windows.net/heat/AssessmentUnits.zip",
              "https://icesoceanography.blob.core.windows.net/heat/Configuration2011-2016.xlsx",
              "https://icesoceanography.blob.core.windows.net/heat/StationSamples2011-2016BOT_2022-12-09.txt.gz",
              "https://icesoceanography.blob.core.windows.net/heat/StationSamples2011-2016CTD_2022-12-09.txt.gz",
              "https://icesoceanography.blob.core.windows.net/heat/StationSamples2011-2016PMP_2022-12-09.txt.gz")
    unitsFile <- file.path(inputPath, "AssessmentUnits.shp")
    configurationFile <- file.path(inputPath, "Configuration2011-2016.xlsx")
    stationSamplesBOTFile <- file.path(inputPath, "StationSamples2011-2016BOT_2022-12-09.txt.gz")
    stationSamplesCTDFile <- file.path(inputPath, "StationSamples2011-2016CTD_2022-12-09.txt.gz")
    stationSamplesPMPFile <- file.path(inputPath, "StationSamples2011-2016PMP_2022-12-09.txt.gz")
  } else if (assessmentPeriod == "2016-2021") {
    urls <- c("https://icesoceanography.blob.core.windows.net/heat/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022_eutro.zip",
              "https://icesoceanography.blob.core.windows.net/heat/Configuration2016-2021.xlsx",
              "https://icesoceanography.blob.core.windows.net/heat/StationSamples2016-2021BOT_2022-12-09.txt.gz",
              "https://icesoceanography.blob.core.windows.net/heat/StationSamples2016-2021CTD_2022-12-09.txt.gz",
              "https://icesoceanography.blob.core.windows.net/heat/StationSamples2016-2021PMP_2022-12-09.txt.gz")
    unitsFile <- file.path(inputPath, "HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022_eutro.shp")
    configurationFile <- file.path(inputPath, "Configuration2016-2021.xlsx")
    stationSamplesBOTFile <- file.path(inputPath, "StationSamples2016-2021BOT_2022-12-09.txt.gz")
    stationSamplesCTDFile <- file.path(inputPath, "StationSamples2016-2021CTD_2022-12-09.txt.gz")
    stationSamplesPMPFile <- file.path(inputPath, "StationSamples2016-2021PMP_2022-12-09.txt.gz")
  }

  # Download the files
  files <- sapply(urls, download.file.unzip.maybe, path = inputPath)
  if (verbose) message("Download and unpack files needed for the assessment... DONE.")

  # Return the paths:
  paths <- list(
    unitsFile=unitsFile,
    configurationFile=configurationFile,
    stationSamplesBOTFile=stationSamplesBOTFile,
    stationSamplesCTDFile=stationSamplesCTDFile,
    stationSamplesPMPFile=stationSamplesPMPFile
  )
  return(paths)
}
