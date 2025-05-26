library(sf)         # %>%, st_...
library(data.table) # setkey, fread, uniqueN
library(readxl)     # read_excel
library(readr)      # read_delim
library(tidyverse)  # select
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


get_indicators_table <- function(configurationFilePath, format='xlsx') {

  if (format=='xlsx') {
    indicatorsTable <- as.data.table(readxl::read_excel(configurationFilePath, sheet = "Indicators", col_types = c("numeric", "numeric", "text", "text", "text", "text", "numeric", "numeric", "numeric", "numeric", "numeric", "numeric", "text", "numeric", "numeric", "text", "numeric", "numeric", "numeric", "numeric", "numeric", "numeric"))) %>% setkey(IndicatorID)
  } else if (format=='csv') {
    indicatorsTable <- as.data.table(readr::read_delim(configurationFilePath, delim=";", col_types = "iicccciiiinncnncnnnnnn")) %>% setkey(IndicatorID)
  }
  return(indicatorsTable)
}


get_indicator_units_table <- function(configurationFilePath, format='xlsx') {

  if (format=='xlsx') {
    indicatorUnitsTable <- as.data.table(readxl::read_excel(configurationFilePath, sheet = "IndicatorUnits", col_types = "numeric")) %>% setkey(IndicatorID, UnitID)
  } else if (format=='csv') {
    indicatorUnitsTable <- as.data.table(readr::read_delim(configurationFilePath, delim=";", col_types = "iinnnnn")) %>% setkey(IndicatorID, UnitID)
  }
  return(indicatorUnitsTable)
}


get_indicator_unit_results_table <- function(configurationFilePath, format='xlsx') {

  if (format=='xlsx') {
    indicatorUnitResultsTable <- as.data.table(readxl::read_excel(configurationFilePath, sheet = "IndicatorUnitResults", col_types = "numeric")) %>% setkey(IndicatorID, UnitID, Period)
  } else if (format=='csv') {
    indicatorUnitResultsTable <- as.data.table(readr::read_delim(configurationFilePath, delim=";", col_types = "iiinninnnnnn")) %>% setkey(IndicatorID, UnitID, Period)
  }
  return(indicatorUnitResultsTable)
}


get_unit_grid_size_table <- function(configurationFilePath, format='xlsx') {

  if (format=='xlsx') {
    unitGridSizeTable <- as.data.table(readxl::read_excel(configurationFilePath, sheet = "UnitGridSize")) %>% data.table::setkey(UnitID)
  } else if (format=='csv') {
    unitGridSizeTable <- as.data.table(readr::read_delim(configurationFilePath, delim=";", col_types = "ii")) %>% setkey(UnitID)
  }
  return(unitGridSizeTable)
}


get_units <- function(assessmentPeriod, unitsFile, verbose=TRUE) {
  if (verbose) message(paste("START: get_units"))

  if (assessmentPeriod == "2011-2016") {
    # Read assessment unit from shape file, requires sf
    units <- sf::st_read(unitsFile)
    
    # Filter for open sea assessment units, requires data.table
    units <- units[units$Code %like% 'SEA',]
    
    # Correct Description column name - temporary solution!
    colnames(units)[2] <- "Description"
    
    # Correct Åland Sea ascii character - temporary solution!
    units[14,2] <- 'Åland Sea'
    
    # Include stations from position 55.86667+-0.01667 12.75+-0.01667 which will include the Danish station KBH/DMU 431 and the Swedish station Wlandskrona into assessment unit 3/SEA-003
    units[3,] <- sf::st_union(units[3,], sf::st_as_sfc("POLYGON((12.73333 55.85,12.73333 55.88334,12.76667 55.88334,12.76667 55.85,12.73333 55.85))", crs = 4326))
    
    # Assign IDs
    units$UnitID = 1:nrow(units)
    
    # Transform projection into ETRS_1989_LAEA
    units <- sf::st_transform(units, crs = 3035)
    
    # Calculate area
    units$UnitArea <- sf::st_area(units)

  } else {
    # Read assessment unit from shape file
    units <- sf::st_read(unitsFile) %>% sf::st_zm()
    
    # Filter for open sea assessment units
    units <- units[units$HELCOM_ID %like% 'SEA',]
    
    # Include stations from position 55.86667+-0.01667 12.75+-0.01667 which will include the Danish station KBH/DMU 431 and the Swedish station Wlandskrona into assessment unit 3/SEA-003
    units[3,] <- sf::st_union(units[3,], sf::st_transform( sf::st_as_sfc("POLYGON((12.73333 55.85,12.73333 55.88334,12.76667 55.88334,12.76667 55.85,12.73333 55.85))", crs = 4326), crs = 3035))
    
    # Order, Rename and Remove columns
    units <- as.data.table(units)[order(HELCOM_ID), .(Code = HELCOM_ID, Description = Name, GEOM = geometry)] %>%
      sf::st_sf()
    
    # Assign IDs
    units$UnitID = 1:nrow(units)

    # Identify invalid geometries
    sf::st_is_valid(units)
    
    # Calculate area
    units$UnitArea <- sf::st_area(units)
  }

  # Identify invalid geometries
  sf::st_is_valid(units)

  # Make geometries valid by doing the buffer of nothing trick
  #units <- sf::st_buffer(units, 0.0)

  # Identify overlapping assessment units
  #st_overlaps(units)

  if (verbose) message(paste("END:   get_units"))
  return(units)
}


get_gridunits <- function(units, unitGridSize, verbose=TRUE) {
  if (verbose) message(paste("START: get_gridunits"))

  gridunits10 <- make.gridunits(units, 10000, verbose)
  gridunits30 <- make.gridunits(units, 30000, verbose)
  gridunits60 <- make.gridunits(units, 60000, verbose)

  a <- merge(unitGridSize[GridSize == 10000], gridunits10 %>% select(UnitID, GridID, GridArea = Area))
  b <- merge(unitGridSize[GridSize == 30000], gridunits30 %>% select(UnitID, GridID, GridArea = Area))
  c <- merge(unitGridSize[GridSize == 60000], gridunits60 %>% select(UnitID, GridID, GridArea = Area))

  gridunits <- sf::st_as_sf(rbindlist(list(a,b,c)))
  gridunits <- sf::st_cast(gridunits)

  rm(a,b,c)

  if (verbose) message(paste("END:   get_gridunits"))
  return(gridunits)
}


make.gridunits <- function(units, gridSize, verbose=TRUE) {
  if (verbose) message(paste("START: make.gridunits for size", gridSize))

  units <- st_transform(units, crs = 3035)

  bbox <- st_bbox(units)

  xmin <- floor(bbox$xmin / gridSize) * gridSize
  ymin <- floor(bbox$ymin / gridSize) * gridSize
  xmax <- ceiling(bbox$xmax / gridSize) * gridSize
  ymax <- ceiling(bbox$ymax / gridSize) * gridSize

  xn <- (xmax - xmin) / gridSize
  yn <- (ymax - ymin) / gridSize

  grid <- st_make_grid(units, cellsize = gridSize, c(xmin, ymin), n = c(xn, yn), crs = 3035) %>%
    st_sf()

  grid$GridID = 1:nrow(grid)

  gridunits <- st_intersection(grid, units)
  gridunits$Area <- st_area(gridunits)

  if (verbose) message(paste("END:   make.gridunits for size", gridSize))
  return(gridunits)
}

parseDateColumn <- function(stationSamplesTable) {
  # If there is no column "Year", we likely have data dowloaded from ICES, which has the date in one column.
  # In this case, separate it into various columns:
  if (!('Year' %in% colnames(stationSamplesTable))){
    message('Column "Year" not found. Looking for other date column.') # TODO Use "missing()" here? For all required columns?
    if ('yyyy.mm.ddThh.mm.ss.sss' %in% colnames(stationSamplesTable)) {
      message('We found column "yyyy.mm.ddThh.mm.ss.sss"... Will try to parse it.')
      stationSamplesTable$tempdate <- as.POSIXct(stationSamplesTable$yyyy.mm.ddThh.mm.ss.sss, format="%Y-%m-%dT%H:%M")
      stationSamplesTable$Year <- lubridate::year(stationSamplesTable$tempdate)
      stationSamplesTable$Month <- lubridate::month(stationSamplesTable$tempdate)
      stationSamplesTable$Day <- lubridate::day(stationSamplesTable$tempdate)
      stationSamplesTable$Hour <- lubridate::hour(stationSamplesTable$tempdate)
      stationSamplesTable$Minute <- lubridate::minute(stationSamplesTable$tempdate)
      #message(paste0('All col names: ', paste(colnames(stationSamplesTable), collapse=',')))
    }
  }
  return(stationSamplesTable)
}



# Difference between column names in HEAT input data provided as part of the GitHub repo,
# and HEAT input data downloaded from ICES database.
# This is how the column names look after importing to R, so we can replace the right side
# by the left side to make sure the script works with freshly downloaded data.
#
# Merret Buurman (IGB Berlin), October 2024
colname_pairs_for_ices_replacement <- list(
  c('Secchi.Depth..m..METAVAR.FLOAT', 'Secchi.Depth..m.'),
  c('Depth..m.', 'Depth..ADEPZZ01_ULAA...m.'),
  c('QV.ODV.Depth..m.', 'QV.ODV.Depth..ADEPZZ01_ULAA.'),
  c('Temperature..degC.', 'Temperature..TEMPPR01_UPAA...degC.'),
  c('QV.ODV.Temperature..degC.', 'QV.ODV.Temperature..TEMPPR01_UPAA.'),
  c('Practical.Salinity..dmnless.', 'Salinity..PSALPR01_UUUU...dmnless.'),
  c('QV.ODV.Practical.Salinity..dmnless.', 'QV.ODV.Salinity..PSALPR01_UUUU.'),
  c('Dissolved.Oxygen..ml.l.', 'Oxygen..DOXYZZXX_UMLL...ml.l.'),
  c('QV.ODV.Dissolved.Oxygen..ml.l.', 'QV.ODV.Oxygen..DOXYZZXX_UMLL.'),
  c('Phosphate.Phosphorus..PO4.P...umol.l.', 'Phosphate..PHOSZZXX_UPOX...umol.l.'),
  c('QV.ODV.Phosphate.Phosphorus..PO4.P...umol.l.', 'QV.ODV.Phosphate..PHOSZZXX_UPOX.'),
  c('Total.Phosphorus..P...umol.l.', 'Total.Phosphorus..TPHSZZXX_UPOX...umol.l.'),
  c('QV.ODV.Total.Phosphorus..P...umol.l.', 'QV.ODV.Total.Phosphorus..TPHSZZXX_UPOX.'),
  c('Silicate.Silicon..SiO4.Si...umol.l.', 'Silicate..SLCAZZXX_UPOX...umol.l.'),
  c('QV.ODV.Silicate.Silicon..SiO4.Si...umol.l.', 'QV.ODV.Silicate..SLCAZZXX_UPOX.'),
  c('Nitrate.Nitrogen..NO3.N...umol.l.', 'Nitrate..NTRAZZXX_UPOX...umol.l.'),
  c('QV.ODV.Nitrate.Nitrogen..NO3.N...umol.l.', 'QV.ODV.Nitrate..NTRAZZXX_UPOX.'),
  c('Nitrite.Nitrogen..NO2.N...umol.l.', 'Nitrite..NTRIZZXX_UPOX...umol.l.'),
  c('QV.ODV.Nitrite.Nitrogen..NO2.N...umol.l.', 'QV.ODV.Nitrite..NTRIZZXX_UPOX.'),
  c('Ammonium.Nitrogen..NH4.N...umol.l.', 'Ammonium..AMONZZXX_UPOX...umol.l.'),
  c('QV.ODV.Ammonium.Nitrogen..NH4.N...umol.l.', 'QV.ODV.Ammonium..AMONZZXX_UPOX.'),
  c('Total.Nitrogen..N...umol.l.', 'Total.Nitrogen..NTOTZZXX_UPOX...umol.l.'),
  c('QV.ODV.Total.Nitrogen..N...umol.l.', 'QV.ODV.Total.Nitrogen..NTOTZZXX_UPOX.'),
  c('Hydrogen.Sulphide..H2S.S...umol.l.', 'Hydrogen.Sulphide..H2SXZZXX_UPOX...umol.l.'),
  c('QV.ODV.Hydrogen.Sulphide..H2S.S...umol.l.', 'QV.ODV.Hydrogen.Sulphide..H2SXZZXX_UPOX.'),
  c('Hydrogen.Ion.Concentration..pH...pH.', 'pH..PHXXZZXX_UUPH...pH.units.'),
  c('QV.ODV.Hydrogen.Ion.Concentration..pH...pH.', 'QV.ODV.pH..PHXXZZXX_UUPH.'),
  c('Alkalinity..mEq.l.', 'Total.Alkalinity..ALKYZZXX_MEQL...mEq.l.'),
  c('QV.ODV.Alkalinity..mEq.l.', 'QV.ODV.Total.Alkalinity..ALKYZZXX_MEQL.'),
  c('Chlorophyll.a..ug.l.', 'Chlorophyll.a..CPHLZZXX_UGPL...ug.l.'),
  c('QV.ODV.Chlorophyll.a..ug.l.', 'QV.ODV.Chlorophyll.a..CPHLZZXX_UGPL.'),
  c('QV.ODV.Bot.Depth..m.', 'TODO_dunno_missing'),
  c('QV.ODV.Secchi.Depth..m.', 'TODO_dunno_missing'),
  c('Pressure..dbar.', 'TODO_dunno_missing'),
  c('QV.ODV.Pressure..dbar.', 'TODO_dunno_missing')
)


replaceColnamesICES <- function(stationSamplesTable, dataset_name, verbose=TRUE, debug=FALSE) {
  # Replace column names in the ICES format by column names the HELCOM format!
  if (verbose) message('Checking/replacing the column names (', dataset_name, ')...')
  if (debug) message(paste('Column names before checking/replacing:', paste(colnames(stationSamplesTable), collapse=', ')))

  # Iterate over all possible pairs for column names (HELCOM/ICES data):
  for (colname_pair in colname_pairs_for_ices_replacement) {

    # Retrieve both names:
    colname_helcom = colname_pair[1]
    colname_ices = colname_pair[2]
    if (debug) message(paste('* colname_helcom: ', colname_helcom))
    if (debug) message(paste('* colname_ices  : ', colname_ices))

    # Check if they occur, replace if applicable:
    if (colname_helcom %in% colnames(stationSamplesTable)) {
      # The data already contains the proper required column name
      if (debug) message(paste0('Colname exists (not replacing): "', colname_helcom, '".'))

    } else {
      if (colname_ices %in% colnames(stationSamplesTable)) {
        # The data contains the new(-ish) ICES column name, whichh has to be replaced...
        if (verbose) message(paste0('Replacing column name           "', colname_ices, '" by "', colname_helcom, '"...'))
        colnames(stationSamplesTable)[colnames(stationSamplesTable)==colname_ices] <- colname_helcom

      } else {
        # None of both column names is present in the data:
        if (debug) message(paste0('Column missing (cannot replace) "', colname_helcom, '" (or its ICES alternative "', colname_ices, '")...'))
      }
    }
  }

  if (verbose) message('Checking/replacing the column names (', dataset_name, ')... DONE.')
  if (debug) message(paste('Column names after checking/replacing:', paste(colnames(stationSamplesTable), collapse=', ')))
  return(stationSamplesTable)
}


prepare_station_samples <- function(stationSamplesBOTFile, stationSamplesCTDFile, stationSamplesPMPFile, gridunits, verbose=TRUE) {
    if (verbose) message("START: prepare_station_samples")

    if (verbose) message("Reading station sample data...")

    # Ocean hydro chemistry - Bottle and low resolution CTD data
    if (is.na(stationSamplesBOTFile)) {
      message('No bottle data provided.')
      stationSamplesBOT <- NULL
    } else {

      # Try reading data with tab separator:
      stationSamplesBOT <- data.table::fread(input = stationSamplesBOTFile, sep = "\t", na.strings = "NULL", stringsAsFactors = FALSE, header = TRUE, check.names = TRUE)

      # Try reading data with comma separator:
      if (ncol(stationSamplesBOT) == 1) {
        message(paste('Only one column found in:', stationSamplesBOTFile))
        message('Probably used the wrong separator (tab). Trying with comma...')
        stationSamplesBOT <- data.table::fread(input = stationSamplesBOTFile, sep = ",", na.strings = "NULL", stringsAsFactors = FALSE, header = TRUE, check.names = TRUE)
      }

      # Set "Type" to B:
      stationSamplesBOT[, Type := "B"]

      # Data that was downloaded from ICES portal recently does not have "Year" etc, but "yyyy.mm.ddThh.mm.ss.sss"...
      if (!('Year' %in% colnames(stationSamplesBOT))){
        stationSamplesBOT <- parseDateColumn(stationSamplesBOT)
      }

      # Data that was downloaded from ICES portal recently may have different column names, that will be an obstacle later in the analysis...
      stationSamplesBOT <- replaceColnamesICES(stationSamplesBOT, 'BOT data', verbose)
    }

    # Ocean hydro chemistry - High resolution CTD data
    if (is.na(stationSamplesCTDFile)) {
      message('No CTD data provided.')
      stationSamplesCTD <- NULL
    } else {

      # Try reading data with tab separator:
      stationSamplesCTD <- data.table::fread(input = stationSamplesCTDFile, sep = "\t", na.strings = "NULL", stringsAsFactors = FALSE, header = TRUE, check.names = TRUE)

      # Try reading data with comma separator:
      if (ncol(stationSamplesCTD) == 1) {
        message(paste('Only one column found in:', stationSamplesCTDFile))
        message('Probably used the wrong separator (tab). Should try with comma...')
        stop('Not implemented yet: Parsing CTD data with comma.') # TODO: Implement this
      }

      # Set "Type" to C:
      stationSamplesCTD[, Type := "C"]

      # Data that was downloaded from ICES portal recently does not have "Year" etc, but "yyyy.mm.ddThh.mm.ss.sss"...
      if (!('Year' %in% colnames(stationSamplesCTD))){
        stationSamplesCTD <- parseDateColumn(stationSamplesCTD)
      }

      # Data that was downloaded from ICES portal recently may have different column names, that will be an obstacle later in the analysis...
      stationSamplesCTD <- replaceColnamesICES(stationSamplesCTD, 'CTD data', verbose)
    }

    # Ocean hydro chemistry - Pump data
    if (is.na(stationSamplesPMPFile)) {
      message('No pump data provided.')
      stationSamplesPMP <- NULL
    } else {

      # Try reading data with tab separator:
      stationSamplesPMP <- data.table::fread(input = stationSamplesPMPFile, sep = "\t", na.strings = "NULL", stringsAsFactors = FALSE, header = TRUE, check.names = TRUE)

      # Try reading data with comma separator:
      if (ncol(stationSamplesPMP) == 1) {
        message(paste('Only one column found in:', stationSamplesPMPFile))
        message('Probably used the wrong separator (tab). Should try with comma...')
        stop('Not implemented yet: Parsing PMP data with comma.') # TODO: Implement this
      }

      # Set "Type" to P:
      stationSamplesPMP[, Type := "P"]

      # Data that was downloaded from ICES portal recently does not have "Year" etc, but "yyyy.mm.ddThh.mm.ss.sss"...
      if (!('Year' %in% colnames(stationSamplesPMP))){
        stationSamplesPMP <- parseDateColumn(stationSamplesPMP)
      }

      # Data that was downloaded from ICES portal recently may have different column names, that will be an obstacle later in the analysis...
      stationSamplesPMP <- replaceColnamesICES(stationSamplesPMP, 'PMP data', verbose)
    }

    # Combine station samples
    stationSamples <- rbindlist(list(stationSamplesBOT, stationSamplesCTD, stationSamplesPMP), use.names = TRUE, fill = TRUE)

    if (length(stationSamples) == 0) {
      stop("Station samples has zero length. Did you provide no input data?")
    }

    # Remove original data tables
    rm(stationSamplesBOT, stationSamplesCTD, stationSamplesPMP)

    # Unique stations by natural key
    if (verbose) message('unique:')
    data.table::uniqueN(stationSamples, by = c("Cruise", "Station", "Type", "Year", "Month", "Day", "Hour", "Minute", "Longitude..degrees_east.", "Latitude..degrees_north."))

    # Assign station ID by natural key
    stationSamples[, StationID := .GRP, by = .(Cruise, Station, Type, Year, Month, Day, Hour, Minute, Longitude..degrees_east., Latitude..degrees_north.)]

    # Classify station samples into grid units -------------------------------------
    if (verbose) message("Classifying station samples into grid units...")

    # Extract unique stations i.e. longitude/latitude pairs
    stations <- unique(stationSamples[, .(Longitude..degrees_east., Latitude..degrees_north.)])
    if (verbose) message(paste('DEBUG: Stations colnames:', paste(colnames(stations), collapse=",")))

    # Make stations spatial keeping original latitude/longitude
    stations <- sf::st_as_sf(stations, coords = c("Longitude..degrees_east.", "Latitude..degrees_north."), remove = FALSE, crs = 4326)

    # Transform projection into ETRS_1989_LAEA
    stations <- sf::st_transform(stations, crs = 3035)

    # Classify stations into grid units
    stations <- sf::st_join(stations, gridunits, join = st_intersects)

    # Delete stations not classified
    stations <- na.omit(stations)

    # Remove spatial column and nake into data table
    stations <- st_set_geometry(stations, NULL) %>% as.data.table()

    # Merge stations back into station samples - getting rid of station samples not classified into assessment units
    stationSamples <- stations[stationSamples, on = .(Longitude..degrees_east., Latitude..degrees_north.), nomatch = 0]

    if (verbose) message("END:   prepare_station_samples")
    return (stationSamples)
}


compute_annual_indicators <- function(stationSamples, units, indicators, indicatorUnits, indicatorUnitResults, combined_Chlorophylla_IsWeighted, verbose=TRUE) {
  if (verbose) message("START: compute_annual_indicators")

  # Loop indicators --------------------------------------------------------------
  if (verbose) message("Looping")
  wk2list = list()
  n <- nrow(indicators[IndicatorID < 1000,])
  for(i in 1:n) {
    indicatorID <- indicators[i, IndicatorID]
    criteriaID <- indicators[i, CriteriaID]
    name <- indicators[i, Name]
    if (verbose) message(paste0("  Iteration ", i, "/", n, ", indicator name: ", name))
    year.min <- indicators[i, YearMin]
    year.max <- indicators[i, YearMax]
    month.min <- indicators[i, MonthMin]
    month.max <- indicators[i, MonthMax]
    depth.min <- indicators[i, DepthMin]
    depth.max <- indicators[i, DepthMax]
    metric <- indicators[i, Metric]
    response <- indicators[i, Response]

    # Copy data
    if (name == 'Chlorophyll a (FB)') {
      wk <- as.data.table(stationSamples[Type == 'P'])     
    } else {
      wk <- as.data.table(stationSamples[Type != 'P'])     
    }
    
    # Create Period
    wk[, Period := ifelse(month.min > month.max & Month >= month.min, Year + 1, Year)]
    
    # Create Indicator
    if (name == 'Dissolved Inorganic Nitrogen') {
      wk$ES <- apply(wk[, list(Nitrate.Nitrogen..NO3.N...umol.l., Nitrite.Nitrogen..NO2.N...umol.l., Ammonium.Nitrogen..NH4.N...umol.l.)], 1, function(x) {
        if (all(is.na(x)) | is.na(x[1])) {
          NA
        }
        else {
          sum(x, na.rm = TRUE)
        }
      })
      wk$ESQ <- apply(wk[, .(QV.ODV.Nitrate.Nitrogen..NO3.N...umol.l., QV.ODV.Nitrite.Nitrogen..NO2.N...umol.l., QV.ODV.Ammonium.Nitrogen..NH4.N...umol.l.)], 1, function(x){
        max(x, na.rm = TRUE)
      })
    } else if (name == 'Dissolved Inorganic Phosphorus') {
      wk[, ES := Phosphate.Phosphorus..PO4.P...umol.l.]
      wk[, ESQ := QV.ODV.Phosphate.Phosphorus..PO4.P...umol.l.]
    } else if (name == 'Chlorophyll a (In-Situ)' | name == 'Chlorophyll a (FB)') {
      wk[, ES := Chlorophyll.a..ug.l.]
      wk[, ESQ := QV.ODV.Chlorophyll.a..ug.l.]
    } else if (name == "Total Nitrogen") {
      wk[, ES := Total.Nitrogen..N...umol.l.]
      wk[, ESQ := QV.ODV.Total.Nitrogen..N...umol.l.]
    } else if (name == "Total Phosphorus") {
      wk[, ES := Total.Phosphorus..P...umol.l.]
      wk[, ESQ := QV.ODV.Total.Phosphorus..P...umol.l.]
    } else if (name == 'Secchi Depth') {
      wk[, ES := Secchi.Depth..m..METAVAR.FLOAT]
      wk[, ESQ := QV.ODV.Secchi.Depth..m.]
    } else {
      next
    }

    # Filter stations rows and columns --> UnitID, GridID, GridArea, Period, Month, StationID, Depth, Temperature, Salinity, ES
    if (month.min > month.max) {
      wk0 <- wk[
        (Period >= year.min & Period <= year.max) &
          (Month >= month.min | Month <= month.max) &
          (Depth..m. >= depth.min & Depth..m. <= depth.max) &
          !is.na(ES) &
          ESQ <= 1 &
          !is.na(UnitID),
        .(IndicatorID = indicatorID, UnitID, GridSize, GridID, GridArea, Period, Month, StationID, Depth = Depth..m., Temperature = Temperature..degC., Salinity = Practical.Salinity..dmnless., ES)]
    } else {
      wk0 <- wk[
        (Period >= year.min & Period <= year.max) &
          (Month >= month.min & Month <= month.max) &
          (Depth..m. >= depth.min & Depth..m. <= depth.max) &
          !is.na(ES) &
          ESQ <= 1 &
          !is.na(UnitID),
        .(IndicatorID = indicatorID, UnitID, GridSize, GridID, GridArea, Period, Month, StationID, Depth = Depth..m., Temperature = Temperature..degC., Salinity = Practical.Salinity..dmnless., ES)]
    }

    # Calculate station depth mean
    wk0 <- wk0[, .(ES = mean(ES), SD = sd(ES), N = .N), keyby = .(IndicatorID, UnitID, GridID, GridArea, Period, Month, StationID, Depth)]
    
    # Calculate station mean --> UnitID, GridID, GridArea, Period, Month, ES, SD, N
    wk1 <- wk0[, .(ES = mean(ES), SD = sd(ES), N = .N), keyby = .(IndicatorID, UnitID, GridID, GridArea, Period, Month, StationID)]
    
    # Calculate annual mean --> UnitID, Period, ES, SD, N, NM
    wk2 <- wk1[, .(ES = mean(ES), SD = sd(ES), N = .N, NM = uniqueN(Month)), keyby = .(IndicatorID, UnitID, Period)]
    
    # Calculate grid area --> UnitID, Period, ES, SD, N, NM, GridArea
    a <- wk1[, .N, keyby = .(IndicatorID, UnitID, Period, GridID, GridArea)] # UnitGrids
    b <- a[, .(GridArea = sum(as.numeric(GridArea))), keyby = .(IndicatorID, UnitID, Period)] #GridAreas
    wk2 <- merge(wk2, b, by = c("IndicatorID", "UnitID", "Period"), all.x = TRUE)
    rm(a,b)

    wk2list[[i]] <- wk2
  }
  if (verbose) message("Looping DONE")

  # Combine annual indicator results
  if (verbose) message("Combine annual indicator results...")
  wk2 <- rbindlist(wk2list)

  # Combine with indicator results reported
  wk2 <- rbindlist(list(wk2, indicatorUnitResults), fill = TRUE)



  # Combine with indicator and indicator unit configuration tables
  if (verbose) message("Combining with indicator and indicator unit configuration tables...")
  wk3 <- indicators[indicatorUnits[wk2]]

  # Calculate General Temporal Confidence (GTC) - Confidence in number of annual observations
  wk3[is.na(GTC), GTC := ifelse(N > GTC_HM, 100, ifelse(N < GTC_ML, 0, 50))]

  # Calculate Number of Months Potential
  wk3[, NMP := ifelse(MonthMin > MonthMax, 12 - MonthMin + 1 + MonthMax, MonthMax - MonthMin + 1)]

  # Calculate Specific Temporal Confidence (STC) - Confidence in number of annual missing months
  wk3[is.na(STC), STC := ifelse(NMP - NM <= STC_HM, 100, ifelse(NMP - NM >= STC_ML, 0, 50))]

  # Calculate General Spatial Confidence (GSC) - Confidence in number of annual observations per number of grids
  #wk3 <- wk3[as.data.table(gridunits)[, .(NG = as.numeric(sum(GridArea) / mean(GridSize^2))), .(UnitID)], on = .(UnitID = UnitID), nomatch=0]
  #wk3[, GSC := ifelse(N / NG > GSC_HM, 100, ifelse(N / NG < GSC_ML, 0, 50))]

  # Calculate Specific Spatial Confidence (SSC) - Confidence in area of sampled grid units as a percentage to the total unit area
  wk3 <- merge(wk3, as.data.table(units)[, .(UnitArea = as.numeric(UnitArea)), keyby = .(UnitID)], by = c("UnitID"), all.x = TRUE)
  wk3[is.na(SSC), SSC := ifelse(GridArea / UnitArea * 100 > SSC_HM, 100, ifelse(GridArea / UnitArea * 100 < SSC_ML, 0, 50))]

  # Calculate Standard Error
  wk3[, SE := SD / sqrt(N)]

  # Calculate 95 % Confidence Interval
  wk3[, CI := qnorm(0.975) * SE]

  # Calculate Eutrophication Ratio (ER)
  wk3[, ER := ifelse(Response == 1, ES / ET, ET / ES)]

  # Calculate (BEST)
  wk3[, BEST := ifelse(Response == 1, ET / (1 + ACDEV / 100), ET / (1 - ACDEV / 100))]

  # Calculate Ecological Quality Ratio (EQR)
  wk3[is.na(EQR), EQR := ifelse(Response == 1, ifelse(BEST > ES, 1, BEST / ES), ifelse(ES > BEST, 1, ES / BEST))]

  # Calculate Ecological Quality Ratio Boundaries (ERQ_HG/GM/MP/PB)
  wk3[is.na(EQR_GM), EQR_GM := ifelse(Response == 1, 1 / (1 + ACDEV / 100), 1 - ACDEV / 100)]
  wk3[is.na(EQR_HG), EQR_HG := 0.5 * 0.95 + 0.5 * EQR_GM]
  wk3[is.na(EQR_PB), EQR_PB := 2 * EQR_GM - 0.95]
  wk3[is.na(EQR_MP), EQR_MP := 0.5 * EQR_GM + 0.5 * EQR_PB]

  # Calculate Ecological Quality Ratio Scaled (EQRS)
  wk3[is.na(EQRS), EQRS := ifelse(EQR <= EQR_PB, (EQR - 0) * (0.2 - 0) / (EQR_PB - 0) + 0,
                                  ifelse(EQR <= EQR_MP, (EQR - EQR_PB) * (0.4 - 0.2) / (EQR_MP - EQR_PB) + 0.2,
                                         ifelse(EQR <= EQR_GM, (EQR - EQR_MP) * (0.6 - 0.4) / (EQR_GM - EQR_MP) + 0.4,
                                                ifelse(EQR <= EQR_HG, (EQR - EQR_GM) * (0.8 - 0.6) / (EQR_HG - EQR_GM) + 0.6,
                                                       (EQR - EQR_HG) * (1 - 0.8) / (1 - EQR_HG) + 0.8))))]

  # Calculate and add combined annual Chlorophyll a (In-Situ/EO/FB) indicator
  if(combined_Chlorophylla_IsWeighted) {
    # Calculate combined chlorophyll a indicator as a weighted average
    wk3[IndicatorID == 501, W := ifelse(UnitID %in% c(12), 0.70, ifelse(UnitID %in% c(13, 14), 0.40, 0.55))]
    wk3[IndicatorID == 502, W := ifelse(UnitID %in% c(12, 13, 14), 0.30, 0.45)]
    wk3[IndicatorID == 503, W := ifelse(UnitID %in% c(13, 14), 0.30, 0.00)]
    wk3_CPHL <- wk3[IndicatorID %in% c(501, 502, 503), .(IndicatorID = 5, ES = weighted.mean(ES, W, na.rm = TRUE), SD = NA, N = sum(N, na.rm = TRUE), NM = max(NM, na.rm = TRUE), ER = weighted.mean(ER, W, na.rm = TRUE), EQR = weighted.mean(EQR, W, na.rm = TRUE), EQRS = weighted.mean(EQRS, W, na.rm = TRUE), GTC = weighted.mean(GTC, W, na.rm = TRUE), NMP = max(NMP, na.rm = TRUE), STC = weighted.mean(STC, W, na.rm = TRUE), SSC = weighted.mean(SSC, W, na.rm = TRUE)), by = .(UnitID, Period)]
    wk3 <- rbindlist(list(wk3, wk3_CPHL), fill = TRUE)
  } else {
    # Calculate combined chlorophyll a indicator as a simple average
    wk3_CPHL <- wk3[IndicatorID %in% c(501, 502, 503), .(IndicatorID = 5, ES = mean(ES, na.rm = TRUE), SD = NA, N = sum(N, na.rm = TRUE), NM = max(NM, na.rm = TRUE), ER = mean(ER, na.rm = TRUE), EQR = mean(EQR, na.rm = TRUE), EQRS = mean(EQRS, na.rm = TRUE), GTC = mean(GTC, na.rm = TRUE), NMP = max(NMP, na.rm = TRUE), STC = mean(STC, na.rm = TRUE), SSC = mean(SSC, na.rm = TRUE)), by = .(UnitID, Period)]
    wk3 <- rbindlist(list(wk3, wk3_CPHL), fill = TRUE)
  }

  # Calculate and add combined annual Cyanobacteria Bloom Index (BM/CSA) indicator
  wk3_CBI <- wk3[IndicatorID %in% c(601, 602), .(IndicatorID = 6, ES = mean(ES, na.rm = TRUE), SD = NA, N = sum(N, na.rm = TRUE), NM = max(NM, na.rm = TRUE), ER = mean(ER, na.rm = TRUE), EQR = mean(EQR, na.rm = TRUE), EQRS = mean(EQRS, na.rm = TRUE), GTC = mean(GTC, na.rm = TRUE), NMP = max(NMP, na.rm = TRUE), STC = mean(STC, na.rm = TRUE), SSC = mean(SSC, na.rm = TRUE)), by = .(UnitID, Period)]
  wk3 <- rbindlist(list(wk3, wk3_CBI), fill = TRUE)

  setkey(wk3, IndicatorID, UnitID, Period)

  # Classify Ecological Quality Ratio Scaled (EQRS_Class)
  wk3[, EQRS_Class := ifelse(EQRS >= 0.8, "High",
                             ifelse(EQRS >= 0.6, "Good",
                                    ifelse(EQRS >= 0.4, "Moderate",
                                           ifelse(EQRS >= 0.2, "Poor","Bad"))))]

  if (verbose) message("END:   compute_annual_indicators")
  return(wk3)
}


compute_assessment_indicators <-function(wk3, indicators, indicatorUnits, verbose=TRUE) {
    if (verbose) message("START: compute_assessment_indicators")

    if (verbose) message("Calculating assessment means...")
    wk4 <- wk3[, .(Period = ifelse(min(Period) > 9999, min(Period), min(Period) * 10000 + max(Period)), ES = mean(ES), SD = sd(ES), ER = mean(ER), EQR = mean(EQR), EQRS = mean(EQRS), N = .N, N_OBS = sum(N), GTC = mean(GTC), STC = mean(STC), SSC = mean(SSC)), .(IndicatorID, UnitID)]

    wk4[, EQRS_Class := ifelse(EQRS >= 0.8, "High",
                        ifelse(EQRS >= 0.6, "Good",
                        ifelse(EQRS >= 0.4, "Moderate",
                        ifelse(EQRS >= 0.2, "Poor","Bad"))))]

    # Add Year Count where STC = 100 --> NSTC100
    wk4 <- wk3[STC == 100, .(NSTC100 = .N), .(IndicatorID, UnitID)][wk4, on = .(IndicatorID, UnitID)]

    # Adjust Specific Spatial Confidence if number of years where STC = 100 is at least half of the number of years with meassurements
    wk4[, STC := ifelse(!is.na(NSTC100) & NSTC100 >= N/2, 100, STC)]

    # Combine with indicator and indicator unit configuration tables
    if (verbose) message("Combining with indicator and indicator unit configuration tables...")
    wk5 <- indicators[indicatorUnits[wk4]]

    # Confidence Assessment---------------------------------------------------------

    if (verbose) message("Confidence assessment...")

    # Calculate Temporal Confidence averaging General and Specific Temporal Confidence 
    wk5 <- wk5[, TC := (GTC + STC) / 2]

    wk5[, TC_Class := ifelse(TC >= 75, "High", ifelse(TC >= 50, "Moderate", "Low"))]

    # Calculate Spatial Confidence as the Specific Spatial Confidence 
    wk5 <- wk5[, SC := SSC]

    wk5[, SC_Class := ifelse(SC >= 75, "High", ifelse(SC >= 50, "Moderate", "Low"))]

    # Standard Error - using number of years in the assessment period and the associated standard deviation
    #wk5[, SE := SD / sqrt(N)]

    # Accuracy Confidence for Non-Problem Area
    #wk5[, AC_NPA := ifelse(Response == 1, pnorm(ET, ES, SD), pnorm(ES, ET, SD))]

    # Standard Error - using number of observations behind the annual mean - to be used in Accuracy Confidence Calculation!!!
    wk5[, AC_SE := SD / sqrt(N_OBS)]

    # Accuracy Confidence for Non-Problem Area
    wk5[, AC_NPA := ifelse(Response == 1, pnorm(ET, ES, AC_SE), pnorm(ES, ET, AC_SE))]

    # Accuracy Confidence for Problem Area
    wk5[, AC_PA := 1 - AC_NPA]

    # Accuracy Confidence Area Class - Not sure what this should be used for?
    #wk5[, ACAC := ifelse(AC_NPA > 0.5, "NPA", ifelse(AC_NPA < 0.5, "PA", "PPA"))]

    # Accuracy Confidence
    wk5[, AC := ifelse(AC_NPA > AC_PA, AC_NPA, AC_PA)]

    # Accuracy Confidence Class
    wk5[, ACC := ifelse(AC > 0.9, 100, ifelse(AC < 0.7, 0, 50))]

    wk5[, ACC_Class := ifelse(ACC >= 75, "High", ifelse(ACC >= 50, "Moderate", "Low"))]

    # Calculate Overall Confidence
    wk5 <- wk5[, C := (TC + SC + ACC) / 3]

    wk5[, C_Class := ifelse(C >= 75, "High", ifelse(C >= 50, "Moderate", "Low"))]

    if (verbose) message("END:   compute_assessment_indicators")
    return(wk5)
}


compute_assessment <- function(wk5, indicators, indicatorUnits, verbose=TRUE) {
    if (verbose) message("START: compute_assessment")

    # Criteria ---------------------------------------------------------------------
    if (verbose) message("Criteria...")

    # Check indicator weights
    if (verbose) message("Check indicator weights...")
    if (verbose) message("(displaying table 'indicators')")
    indicators[indicatorUnits][!is.na(CriteriaID), .(IWs = sum(IW, na.rm = TRUE)), .(CriteriaID, UnitID)]

    # Criteria result as a simple average of the indicators in each category per unit - CategoryID, UnitID, N, ER, EQR, EQRS, C
    if (verbose) message("Computing criteria result...")
    wk6 <- wk5[!is.na(CriteriaID) & !is.na(EQRS), .(.N, ER = mean(ER), EQR = mean(EQR), EQRS = mean(EQRS), C = mean(C)), .(CriteriaID, UnitID)]

    # Criteria result as a weighted average of the indicators in each category per unit - CategoryID, UnitID, N, ER, EQR, EQRS, C
    #wk6 <- wk5[!is.na(CriteriaID) & !is.na(EQR), .(.N, ER = weighted.mean(ER, IW, na.rm = TRUE), EQR = weighted.mean(EQR, IW, na.rm = TRUE), EQRS = weighted.mean(EQRS, IW, na.rm = TRUE), C = weighted.mean(C, IW, na.rm = TRUE)), .(CriteriaID, UnitID)]

    wk7 <- dcast(wk6, UnitID ~ CriteriaID, value.var = c("N","ER","EQR","EQRS","C"))

    # Assessment -------------------------------------------------------------------
    if (verbose) message("Assessment...")

    # Assessment result - UnitID, N, ER, EQR, EQRS, C
    wk8 <- wk6[, .(.N, ER = max(ER), EQR = min(EQR), EQRS = min(EQRS), C = mean(C)), (UnitID)] %>% setkey(UnitID)

    wk9 <- wk7[wk8, on = .(UnitID = UnitID), nomatch=0]

    # Assign Status and Confidence Classes
    wk9[, EQRS_Class   := ifelse(EQRS >= 0.8, "High",
                          ifelse(EQRS >= 0.6, "Good",
                          ifelse(EQRS >= 0.4, "Moderate",
                          ifelse(EQRS >= 0.2, "Poor","Bad"))))]
    wk9[, EQRS_1_Class := ifelse(EQRS_1 >= 0.8, "High",
                          ifelse(EQRS_1 >= 0.6, "Good",
                          ifelse(EQRS_1 >= 0.4, "Moderate",
                          ifelse(EQRS_1 >= 0.2, "Poor","Bad"))))]
    wk9[, EQRS_2_Class := ifelse(EQRS_2 >= 0.8, "High",
                          ifelse(EQRS_2 >= 0.6, "Good",
                          ifelse(EQRS_2 >= 0.4, "Moderate",
                          ifelse(EQRS_2 >= 0.2, "Poor","Bad"))))]
    wk9[, EQRS_3_Class := ifelse(EQRS_3 >= 0.8, "High",
                          ifelse(EQRS_3 >= 0.6, "Good",
                          ifelse(EQRS_3 >= 0.4, "Moderate",
                          ifelse(EQRS_3 >= 0.2, "Poor","Bad"))))]

    wk9[, C_Class   := ifelse(C >= 75, "High",
                       ifelse(C >= 50, "Moderate", "Low"))]
    wk9[, C_1_Class := ifelse(C_1 >= 75, "High",
                       ifelse(C_1 >= 50, "Moderate", "Low"))]
    wk9[, C_2_Class := ifelse(C_2 >= 75, "High",
                       ifelse(C_2 >= 50, "Moderate", "Low"))]
    wk9[, C_3_Class := ifelse(C_3 >= 75, "High",
                       ifelse(C_3 >= 50, "Moderate", "Low"))]

    if (verbose) message("END:   compute_assessment")
    return(wk9)
}

