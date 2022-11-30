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
  urls <- c("https://www.dropbox.com/s/r14qdxdic8l39tq/Auxilliary.csv?dl=1",
            "https://www.dropbox.com/s/xgt9gp4syz71d6j/Nitrogen.csv?dl=1",
            "https://www.dropbox.com/s/421phd1b9aszc0z/MajorBalticInflows.csv?dl=1",
            "https://www.dropbox.com/s/d7yyrd77f5gc2sc/Baltsem_utm34.zip?dl=1",
            "https://www.dropbox.com/s/nz4ffydakewl7so/BALTIC_BATHY_BALTSEM.zip?dl=1",
            "https://www.dropbox.com/s/rub2x8k4d2qy8cu/AssessmentUnits.zip?dl=1",
            "https://www.dropbox.com/s/txm63nuqyu2kgtw/StationSamples2011-2016BOT_2022-11-30.txt.gz?dl=1",
            "https://www.dropbox.com/s/264vysa89dfmszv/StationSamples2011-2016CTD_2022-11-30.txt.gz?dl=1")
  auxilliaryFile <- file.path(inputPath, "Auxilliary.csv")
  nitrogenFile <- file.path(inputPath, "Nitrogen.csv")
  majorBalticInflowsFile <- file.path(inputPath, "MajorBalticInflows.csv")
  baltsemUnitsFile <- file.path(inputPath, "Baltsem_utm34.shp")
  baltsemBathymetricFile <- file.path(inputPath, "BALTIC_BATHY_BALTSEM.csv")
  unitsFile <- file.path(inputPath, "AssessmentUnits.shp")
  stationSamplesBOTFile <- file.path(inputPath, "StationSamples2011-2016BOT_2022-11-30.txt.gz")
  stationSamplesCTDFile <- file.path(inputPath, "StationSamples2011-2016CTD_2022-11-30.txt.gz")
} else if (assessmentPeriod == "2016-2021") {
  urls <- c("https://www.dropbox.com/s/r14qdxdic8l39tq/Auxilliary.csv?dl=1",
            "https://www.dropbox.com/s/xgt9gp4syz71d6j/Nitrogen.csv?dl=1",
            "https://www.dropbox.com/s/421phd1b9aszc0z/MajorBalticInflows.csv?dl=1",
            "https://www.dropbox.com/s/d7yyrd77f5gc2sc/Baltsem_utm34.zip?dl=1",
            "https://www.dropbox.com/s/nz4ffydakewl7so/BALTIC_BATHY_BALTSEM.zip?dl=1",
            "https://www.dropbox.com/s/rub2x8k4d2qy8cu/AssessmentUnits.zip?dl=1",
            "https://www.dropbox.com/s/dn6zud3ugr1a2tx/StationSamples2016-2021BOT_2022-11-30.txt.gz?dl=1",
            "https://www.dropbox.com/s/pbjw7fdmoo4tqmh/StationSamples2016-2021CTD_2022-11-30.txt.gz?dl=1")
  auxilliaryFile <- file.path(inputPath, "Auxilliary.csv")
  nitrogenFile <- file.path(inputPath, "Nitrogen.csv")
  majorBalticInflowsFile <- file.path(inputPath, "MajorBalticInflows.csv")
  baltsemUnitsFile <- file.path(inputPath, "Baltsem_utm34.shp")
  baltsemBathymetricFile <- file.path(inputPath, "BALTIC_BATHY_BALTSEM.csv")
  unitsFile <- file.path(inputPath, "AssessmentUnits.shp")
  stationSamplesBOTFile <- file.path(inputPath, "StationSamples2016-2021BOT_2022-11-30.txt.gz")
  stationSamplesCTDFile <- file.path(inputPath, "StationSamples2016-2021CTD_2022-11-30.txt.gz")
}

files <- sapply(urls, download.file.unzip.maybe, path = inputPath)
