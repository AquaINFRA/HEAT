# ----------------------------
#
#   download data
#
# ----------------------------

# load packages etc.
header("data")

# Define paths
inputPath <<- file.path("OxygenDebt/Input", assessmentPeriod)
outputPath <<- file.path("OxygenDebt/Output", assessmentPeriod)

# Create paths
dir.create(inputPath, showWarnings = FALSE, recursive = TRUE)
dir.create(outputPath, showWarnings = FALSE, recursive = TRUE)

# Download and unpack files needed for the oxygen debt indicator ---------------
download.file.unzip.maybe <- function(url, refetch = FALSE, path = ".") {
  dest <- file.path(path, sub("\\?.+", "", basename(url)))
  if (refetch || !file.exists(dest)) {
    download.file(url, dest, mode = "wb")
    if (tools::file_ext(dest) == "zip") {
      unzip(dest, exdir = path)
    }
  }
}

urls <- c()
configFile <- file.path(inputPath, "")
auxilliaryFile <- file.path(inputPath, "")
nitrogenFile <- file.path(inputPath, "")
majorBalticInflowsFile <- file.path(inputPath, "")
baltsemUnitsFile <- file.path(inputPath, "")
baltsemBathymetricFile <- file.path(inputPath, "")
unitsFile <- file.path(inputPath, "")
stationSamplesBOTFile <- file.path(inputPath, "")
stationSamplesCTDFile <- file.path(inputPath, "")

if (assessmentPeriod == "2011-2016"){
  urls <- c("https://icesoceanography.blob.core.windows.net/heat/OxygenDebt/Auxilliary.csv",
            "https://icesoceanography.blob.core.windows.net/heat/OxygenDebt/Nitrogen.csv",
            "https://icesoceanography.blob.core.windows.net/heat/OxygenDebt/MajorBalticInflows.csv",
            "https://icesoceanography.blob.core.windows.net/heat/OxygenDebt/Baltsem_utm34.zip",
            "https://icesoceanography.blob.core.windows.net/heat/OxygenDebt/BALTIC_BATHY_BALTSEM.zip",
            "https://icesoceanography.blob.core.windows.net/heat/AssessmentUnits.zip",
            "https://icesoceanography.blob.core.windows.net/heat/StationSamples2011-2016BOT_2022-12-09.txt.gz",
            "https://icesoceanography.blob.core.windows.net/heat/StationSamples2011-2016CTD_2022-12-09.txt.gz")
  auxilliaryFile <- file.path(inputPath, "Auxilliary.csv")
  nitrogenFile <- file.path(inputPath, "Nitrogen.csv")
  majorBalticInflowsFile <- file.path(inputPath, "MajorBalticInflows.csv")
  baltsemUnitsFile <- file.path(inputPath, "Baltsem_utm34.shp")
  baltsemBathymetricFile <- file.path(inputPath, "BALTIC_BATHY_BALTSEM.csv")
  unitsFile <- file.path(inputPath, "AssessmentUnits.shp")
  stationSamplesBOTFile <- file.path(inputPath, "StationSamples2011-2016BOT_2022-12-09.txt.gz")
  stationSamplesCTDFile <- file.path(inputPath, "StationSamples2011-2016CTD_2022-12-09.txt.gz")
} else if (assessmentPeriod == "2016-2021") {
  urls <- c("https://icesoceanography.blob.core.windows.net/heat/OxygenDebt/Auxilliary.csv",
            "https://icesoceanography.blob.core.windows.net/heat/OxygenDebt/Nitrogen.csv",
            "https://icesoceanography.blob.core.windows.net/heat/OxygenDebt/MajorBalticInflows.csv",
            "https://icesoceanography.blob.core.windows.net/heat/OxygenDebt/Baltsem_utm34.zip",
            "https://icesoceanography.blob.core.windows.net/heat/OxygenDebt/BALTIC_BATHY_BALTSEM.zip",
            "https://icesoceanography.blob.core.windows.net/heat/AssessmentUnits.zip",
            "https://icesoceanography.blob.core.windows.net/heat/StationSamples2016-2021BOT_2022-12-09.txt.gz",
            "https://icesoceanography.blob.core.windows.net/heat/StationSamples2016-2021CTD_2022-12-09.txt.gz")
  auxilliaryFile <- file.path(inputPath, "Auxilliary.csv")
  nitrogenFile <- file.path(inputPath, "Nitrogen.csv")
  majorBalticInflowsFile <- file.path(inputPath, "MajorBalticInflows.csv")
  baltsemUnitsFile <- file.path(inputPath, "Baltsem_utm34.shp")
  baltsemBathymetricFile <- file.path(inputPath, "BALTIC_BATHY_BALTSEM.csv")
  unitsFile <- file.path(inputPath, "AssessmentUnits.shp")
  stationSamplesBOTFile <- file.path(inputPath, "StationSamples2016-2021BOT_2022-12-09.txt.gz")
  stationSamplesCTDFile <- file.path(inputPath, "StationSamples2016-2021CTD_2022-12-09.txt.gz")
}

files <- sapply(urls, download.file.unzip.maybe, path = inputPath)
