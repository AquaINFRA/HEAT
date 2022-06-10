# Install and load R packages ---------------------------------------------
ipak <- function(pkg){
  new.pkg <- pkg[!(pkg %in% installed.packages()[, "Package"])]
  if (length(new.pkg)) 
    install.packages(new.pkg, dependencies = TRUE)
  sapply(pkg, require, character.only = TRUE)
}
packages <- c("sf", "data.table", "tidyverse", "readxl", "ggplot2", "ggmap", "mapview", "httr", "R.utils")
ipak(packages)

# Define assessment period i.e. uncomment the period you want to run the assessment for!
#assessmentPeriod <- "2011-2016" # HOLAS II
assessmentPeriod <- "2016-2021" # HOLAS III

# Define paths
inputPath <- file.path("Input", assessmentPeriod)
outputPath <- file.path("Output", assessmentPeriod)

# Create paths
dir.create(inputPath, showWarnings = FALSE, recursive = TRUE)
dir.create(outputPath, showWarnings = FALSE, recursive = TRUE)

# Download and unpack files needed for the assessment --------------------------
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
unitsFile <- file.path(inputPath, "")
configurationFile <- file.path(inputPath, "")
stationSamplesBOTFile <- file.path(inputPath, "")
stationSamplesCTDFile <- file.path(inputPath, "")
stationSamplesPMPFile <- file.path(inputPath, "")

if (assessmentPeriod == "2011-2016"){
  urls <- c("https://www.dropbox.com/s/rub2x8k4d2qy8cu/AssessmentUnits.zip?dl=1",
            "https://www.dropbox.com/s/nzcllbb1vf7plvq/Configuration2011-2016.xlsx?dl=1",
            "https://www.dropbox.com/s/3vb45x15le7ihxa/StationSamples2011-2016BOT.txt.gz?dl=1",
            "https://www.dropbox.com/s/unm5bics6229qbo/StationSamples2011-2016CTD.txt.gz?dl=1",
            "https://www.dropbox.com/s/sx5u9lrk9pnrx0v/StationSamples2011-2016PMP.txt.gz?dl=1")
  unitsFile <- file.path(inputPath, "AssessmentUnits.shp")
  configurationFile <- file.path(inputPath, "Configuration2011-2016.xlsx")
  stationSamplesBOTFile <- file.path(inputPath, "StationSamples2011-2016BOT.txt.gz")
  stationSamplesCTDFile <- file.path(inputPath, "StationSamples2011-2016CTD.txt.gz")
  stationSamplesPMPFile <- file.path(inputPath, "StationSamples2011-2016PMP.txt.gz")
} else if (assessmentPeriod == "2016-2021") {
  urls <- c("https://www.dropbox.com/s/8g3ue0v0qmnhqut/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022_eutro3.zip?dl=1",
            "https://www.dropbox.com/s/tp5yh0v92faica2/Configuration2016-2021.xlsx?dl=1",
            "https://www.dropbox.com/s/skv0kfpq5w32kt1/StationSamples2016-2021BOT.txt.gz?dl=1",
            "https://www.dropbox.com/s/mbpaxniqhi88m6u/StationSamples2016-2021CTD.txt.gz?dl=1",
            "https://www.dropbox.com/s/xtn23w8j04y6ljn/StationSamples2016-2021PMP.txt.gz?dl=1")
  unitsFile <- file.path(inputPath, "HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022_eutro.shp")
  configurationFile <- file.path(inputPath, "Configuration2016-2021.xlsx")
  stationSamplesBOTFile <- file.path(inputPath, "StationSamples2016-2021BOT.txt.gz")
  stationSamplesCTDFile <- file.path(inputPath, "StationSamples2016-2021CTD.txt.gz")
  stationSamplesPMPFile <- file.path(inputPath, "StationSamples2016-2021PMP.txt.gz")
}

files <- sapply(urls, download.file.unzip.maybe, path = inputPath)

# Assessment Units + Grid Units-------------------------------------------------

if (assessmentPeriod == "2011-2016") {
  # Read assessment unit from shape file
  units <- st_read(unitsFile)
  
  # Filter for open sea assessment units
  units <- units[units$Code %like% 'SEA',]
  
  # Correct Description column name - temporary solution!
  colnames(units)[2] <- "Description"
  
  # Correct Åland Sea ascii character - temporary solution!
  units[14,2] <- 'Åland Sea'
  
  # Include stations from position 55.86667+-0.01667 12.75+-0.01667 which will include the Danish station KBH/DMU 431 and the Swedish station Wlandskrona into assessment unit 3/SEA-003
  units[3,] <- st_union(units[3,],st_as_sfc("POLYGON((12.73333 55.85,12.73333 55.88334,12.76667 55.88334,12.76667 55.85,12.73333 55.85))", crs = 4326))
  
  # Assign IDs
  units$UnitID = 1:nrow(units)
  
  # Transform projection into ETRS_1989_LAEA
  units <- st_transform(units, crs = 3035)
  
  # Calculate area
  units$UnitArea <- st_area(units)
} else if (assessmentPeriod == "2016-2021") {
  # Read assessment unit from shape file
  units <- st_read(unitsFile)
  
  # Filter for open sea assessment units
  units <- units[units$HELCOM_ID %like% 'SEA',]
  
  # Include stations from position 55.86667+-0.01667 12.75+-0.01667 which will include the Danish station KBH/DMU 431 and the Swedish station Wlandskrona into assessment unit 3/SEA-003
  units[3,] <- st_union(units[3,],st_transform(st_as_sfc("POLYGON((12.73333 55.85,12.73333 55.88334,12.76667 55.88334,12.76667 55.85,12.73333 55.85))", crs = 4326), crs = 3035))
  
  # Order, Rename and Remove columns
  units <- as.data.table(units)[order(HELCOM_ID), .(Code = HELCOM_ID, Description = Name, GEOM = geometry)] %>%
    st_sf()
  
  # Assign IDs
  units$UnitID = 1:nrow(units)

  # Identify invalid geometries
  st_is_valid(units)
  
  # Calculate area
  units$UnitArea <- st_area(units)
}

# Identify invalid geometries
st_is_valid(units)

# Make geometries valid by doing the buffer of nothing trick
#units <- sf::st_buffer(units, 0.0)

# Identify overlapping assessment units
#st_overlaps(units)

# Make grid units
make.gridunits <- function(units, gridSize) {
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
  
  return(gridunits)
}

gridunits10 <- make.gridunits(units, 10000)
gridunits30 <- make.gridunits(units, 30000)
gridunits60 <- make.gridunits(units, 60000)

unitGridSize <- as.data.table(read_excel(configurationFile, sheet = "UnitGridSize")) %>% setkey(UnitID)

a <- merge(unitGridSize[GridSize == 10000], gridunits10 %>% select(UnitID, GridID, GridArea = Area))
b <- merge(unitGridSize[GridSize == 30000], gridunits30 %>% select(UnitID, GridID, GridArea = Area))
c <- merge(unitGridSize[GridSize == 60000], gridunits60 %>% select(UnitID, GridID, GridArea = Area))
gridunits <- st_as_sf(rbindlist(list(a,b,c)))
rm(a,b,c)

gridunits <- st_cast(gridunits)

#st_write(gridunits, file.path(outputPath, "gridunits.shp"), delete_layer = TRUE)

# Plot
ggplot() + geom_sf(data = units) + coord_sf()
ggsave(file.path(outputPath, "Assessment_Units.png"), width = 12, height = 9, dpi = 300)
ggplot() + geom_sf(data = gridunits10) + coord_sf()
ggsave(file.path(outputPath, "Assessment_GridUnits10.png"), width = 12, height = 9, dpi = 300)
ggplot() + geom_sf(data = gridunits30) + coord_sf()
ggsave(file.path(outputPath, "Assessment_GridUnits30.png"), width = 12, height = 9, dpi = 300)
ggplot() + geom_sf(data = gridunits60) + coord_sf()
ggsave(file.path(outputPath, "Assessment_GridUnits60.png"), width = 12, height = 9, dpi = 300)
ggplot() + geom_sf(data = st_cast(gridunits)) + coord_sf()
ggsave(file.path(outputPath, "Assessment_GridUnits.png"), width = 12, height = 9, dpi = 300)

# Read station sample data -----------------------------------------------------

# Ocean hydro chemistry - Bottle and low resolution CTD data
stationSamplesBOT <- fread(input = stationSamplesBOTFile, sep = "\t", na.strings = "NULL", stringsAsFactors = FALSE, header = TRUE, check.names = TRUE)
stationSamplesBOT[, Type := "B"]

# Ocean hydro chemistry - High resolution CTD data
stationSamplesCTD <- fread(input = stationSamplesCTDFile, sep = "\t", na.strings = "NULL", stringsAsFactors = FALSE, header = TRUE, check.names = TRUE)
stationSamplesCTD[, Type := "C"]

# Ocean hydro chemistry - Pump data
#stationSamplesPMP <- fread(input = stationSamplesPMPFile, sep = "\t", na.strings = "NULL", stringsAsFactors = FALSE, header = TRUE, check.names = TRUE)
#stationSamplesPMP[, Type := "P"]

# Combine station samples
#stationSamples <- rbindlist(list(stationSamplesBOT, stationSamplesCTD, stationSamplesPMP), use.names = TRUE, fill = TRUE)
stationSamples <- rbindlist(list(stationSamplesBOT, stationSamplesCTD), use.names = TRUE, fill = TRUE)

# Remove original data tables
#rm(stationSamplesBOT, stationSamplesCTD, stationSamplesPMP)
rm(stationSamplesBOT, stationSamplesCTD)

# Unique stations by natural key
uniqueN(stationSamples, by = c("Cruise", "Station", "Type", "Year", "Month", "Day", "Hour", "Minute", "Longitude..degrees_east.", "Latitude..degrees_north."))

# Assign station ID by natural key
stationSamples[, StationID := .GRP, by = .(Cruise, Station, Type, Year, Month, Day, Hour, Minute, Longitude..degrees_east., Latitude..degrees_north.)]

# Classify station samples into grid units -------------------------------------

# Extract unique stations i.e. longitude/latitude pairs
stations <- unique(stationSamples[, .(Longitude..degrees_east., Latitude..degrees_north.)])

# Make stations spatial keeping original latitude/longitude
stations <- st_as_sf(stations, coords = c("Longitude..degrees_east.", "Latitude..degrees_north."), remove = FALSE, crs = 4326)

# Transform projection into ETRS_1989_LAEA
stations <- st_transform(stations, crs = 3035)

# Classify stations into grid units
stations <- st_join(stations, gridunits, join = st_intersects)

# Delete stations not classified
stations <- na.omit(stations)

# Remove spatial column and nake into data table
stations <- st_set_geometry(stations, NULL) %>% as.data.table()

# Merge stations back into station samples - getting rid of station samples not classified into assessment units
stationSamples <- stations[stationSamples, on = .(Longitude..degrees_east., Latitude..degrees_north.), nomatch = 0]

# Read indicator configs -------------------------------------------------------
indicators <- as.data.table(read_excel(configurationFile, sheet = "Indicators")) %>% setkey(IndicatorID)
indicatorUnits <- as.data.table(read_excel(configurationFile, sheet = "IndicatorUnits")) %>% setkey(IndicatorID, UnitID)
indicatorUnitResults <- as.data.table(read_excel(configurationFile, sheet = "IndicatorUnitResults")) %>% setkey(IndicatorID, UnitID, Period)

wk2list = list()

# Loop indicators --------------------------------------------------------------
for(i in 1:nrow(indicators)){
  indicatorID <- indicators[i, IndicatorID]
  criteriaID <- indicators[i, CriteriaID]
  name <- indicators[i, Name]
  year.min <- indicators[i, YearMin]
  year.max <- indicators[i, YearMax]
  month.min <- indicators[i, MonthMin]
  month.max <- indicators[i, MonthMax]
  depth.min <- indicators[i, DepthMin]
  depth.max <- indicators[i, DepthMax]
  metric <- indicators[i, Metric]
  response <- indicators[i, Response]

  # Copy data
  wk <- as.data.table(stationSamples)  
  
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
  } else if (name == 'Chlorophyll a (In-Situ)') {
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

# Combine annual indicator results
wk2 <- rbindlist(wk2list)

# ------------------------------------------------------------------------------

# Combine with indicator results reported
wk2 <- rbindlist(list(wk2, indicatorUnitResults), fill = TRUE)

# Calculate and add combined annual Chlorophyll a (In-Situ/EO/FB) indicator
wk2_CPHL <- wk2[IndicatorID %in% c(501, 502, 503), .(IndicatorID = 5, ES = mean(ES), SD = NA, N = sum(N), NM = max(NM), GridArea = max(GridArea), EQR = mean(EQR), EQRS = mean(EQRS)), by = .(UnitID, Period)]
wk2 <- rbindlist(list(wk2, wk2_CPHL), fill = TRUE)

# Calculate and add combined annual Cyanobacteria Bloom Index (BM/CSA) indicator
wk2_CBI <- wk2[IndicatorID %in% c(601, 602), .(IndicatorID = 6, ES = mean(ES), SD = NA, N = sum(N), NM = max(NM), GridArea = max(GridArea), EQR = mean(EQR), EQRS = mean(EQRS)), by = .(UnitID, Period)]
wk2 <- rbindlist(list(wk2, wk2_CBI), fill = TRUE)

setkey(wk2, IndicatorID, UnitID, Period)

# ------------------------------------------------------------------------------

# Combine with indicator and indicator unit configuration tables
wk3 <- indicators[indicatorUnits[wk2]]

# Calculate General Temporal Confidence (GTC) - Confidence in number of annual observations
wk3[, GTC := ifelse(N > GTC_HM, 100, ifelse(N < GTC_ML, 0, 50))]

# Calculate Number of Months Potential
wk3[, NMP := ifelse(MonthMin > MonthMax, 12 - MonthMin + 1 + MonthMax, MonthMax - MonthMin + 1)]

# Calculate Specific Temporal Confidence (STC) - Confidence in number of annual missing months
wk3[, STC := ifelse(NMP - NM <= STC_HM, 100, ifelse(NMP - NM >= STC_ML, 0, 50))]

# Calculate General Spatial Confidence (GSC) - Confidence in number of annual observations per number of grids
#wk3 <- wk3[as.data.table(gridunits)[, .(NG = as.numeric(sum(GridArea) / mean(GridSize^2))), .(UnitID)], on = .(UnitID = UnitID), nomatch=0]
#wk3[, GSC := ifelse(N / NG > GSC_HM, 100, ifelse(N / NG < GSC_ML, 0, 50))]

# Calculate Specific Spatial Confidence (SSC) - Confidence in area of sampled grid units as a percentage to the total unit area
wk3 <- merge(wk3, as.data.table(units)[, .(UnitArea = as.numeric(UnitArea)), keyby = .(UnitID)], by = c("UnitID"), all.x = TRUE)
wk3[, SSC := ifelse(GridArea / UnitArea * 100 > SSC_HM, 100, ifelse(GridArea / UnitArea * 100 < SSC_ML, 0, 50))]

# ------------------------------------------------------------------------------

# Standard Error
wk3[, SE := SD / sqrt(N)]

# 95 % Confidence Interval
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

wk3[, EQRS_Class := ifelse(EQRS >= 0.8, "High",
                           ifelse(EQRS >= 0.6, "Good",
                                  ifelse(EQRS >= 0.4, "Moderate",
                                         ifelse(EQRS >= 0.2, "Poor","Bad"))))]

# ------------------------------------------------------------------------------

# Calculate assessment means --> UnitID, Period, ES, SD, N, N_OBS, EQR, EQRS GTC, STC, SSC
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
wk5 <- indicators[indicatorUnits[wk4]]

# Confidence Assessment---------------------------------------------------------

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

# Criteria ---------------------------------------------------------------------

# Check indicator weights
indicators[indicatorUnits][!is.na(CriteriaID), .(IWs = sum(IW, na.rm = TRUE)), .(CriteriaID, UnitID)]

# Criteria result as a simple average of the indicators in each category per unit - CategoryID, UnitID, N, ER, EQR, EQRS, C
wk6 <- wk5[!is.na(CriteriaID) & !is.na(EQR), .(.N, ER = mean(ER), EQR = mean(EQR), EQRS = mean(EQRS), C = mean(C)), .(CriteriaID, UnitID)]

# Criteria result as a weighted average of the indicators in each category per unit - CategoryID, UnitID, N, ER, EQR, EQRS, C
#wk6 <- wk5[!is.na(CriteriaID) & !is.na(EQR), .(.N, ER = weighted.mean(ER, IW, na.rm = TRUE), EQR = weighted.mean(EQR, IW, na.rm = TRUE), EQRS = weighted.mean(EQRS, IW, na.rm = TRUE), C = weighted.mean(C, IW, na.rm = TRUE)), .(CriteriaID, UnitID)]

wk7 <- dcast(wk6, UnitID ~ CriteriaID, value.var = c("N","ER","EQR","EQRS","C"))

# Assessment -------------------------------------------------------------------

# Assessment result - UnitID, N, ER, EQR, EQRS, C
wk8 <- wk6[, .(.N, ER = max(ER), EQR = min(EQR), EQRS = min(EQRS), C = mean(C)), (UnitID)] %>% setkey(UnitID)

wk9 <- wk7[wk8, on = .(UnitID = UnitID), nomatch=0]

# Assign Status and Confidence Classes
wk9[, EQRS_Class := ifelse(EQRS >= 0.8, "High",
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

wk9[, C_Class := ifelse(C >= 75, "High",
                        ifelse(C >= 50, "Moderate", "Low"))]
wk9[, C_1_Class := ifelse(C_1 >= 75, "High",
                        ifelse(C_1 >= 50, "Moderate", "Low"))]
wk9[, C_2_Class := ifelse(C_2 >= 75, "High",
                        ifelse(C_2 >= 50, "Moderate", "Low"))]
wk9[, C_3_Class := ifelse(C_3 >= 75, "High",
                        ifelse(C_3 >= 50, "Moderate", "Low"))]

# Write results
fwrite(wk3, file = file.path(outputPath, "Annual_Indicator.csv"))
fwrite(wk5, file = file.path(outputPath, "Assessment_Indicator.csv"))
fwrite(wk9, file = file.path(outputPath, "Assessment.csv"))

# Create plots
EQRS_Class_colors <- c(rgb(119,184,143,max=255), rgb(186,215,194,max=255), rgb(235,205,197,max=255), rgb(216,161,151,max=255), rgb(199,122,112,max=255))
EQRS_Class_limits <- c("High", "Good", "Moderate", "Poor", "Bad")
EQRS_Class_labels <- c(">= 0.8 - 1.0 (High)", ">= 0.6 - 0.8 (Good)", ">= 0.4 - 0.6 (Moderate)", ">= 0.2 - 0.4 (Poor)", ">= 0.0 - 0.2 (Bad)")

C_Class_colors <- c(rgb(252,231,218,max=255), rgb(245,183,142,max=255), rgb(204,100,23,max=255))
C_Class_limits <- c("High", "Moderate", "Low")
C_Class_labels <- c(">= 75 % (High)", "50 - 74 % (Moderate)", "< 50 % (Low)")

# Assessment map Status + Confidence
wk <- merge(units, wk9, all.x = TRUE, by = "UnitID")

# Status maps
ggplot(wk) +
  ggtitle(label = paste0("Eutrophication Status ", assessmentPeriod)) +
  geom_sf(aes(fill = EQRS_Class)) +
  scale_fill_manual(name = "EQRS", values = EQRS_Class_colors, limits = EQRS_Class_limits, labels = EQRS_Class_labels)
ggsave(file.path(outputPath, "Assessment_Map_EQRS.png"), width = 12, height = 9, dpi = 300)

ggplot(wk) +
  ggtitle(label = paste0("Eutrophication Status ", assessmentPeriod)) +
  geom_sf(aes(fill = EQRS_1_Class)) +
  scale_fill_manual(name = "EQRS_1", values = EQRS_Class_colors, limits = EQRS_Class_limits, labels = EQRS_Class_labels)
ggsave(file.path(outputPath, "Assessment_Map_EQRS_1.png"), width = 12, height = 9, dpi = 300)

ggplot(wk) +
  ggtitle(label = paste0("Eutrophication Status ", assessmentPeriod)) +
  geom_sf(aes(fill = EQRS_2_Class)) +
  scale_fill_manual(name = "EQRS_2", values = EQRS_Class_colors, limits = EQRS_Class_limits, labels = EQRS_Class_labels)
ggsave(file.path(outputPath, "Assessment_Map_EQRS_2.png"), width = 12, height = 9, dpi = 300)

ggplot(wk) +
  ggtitle(label = paste0("Eutrophication Status ", assessmentPeriod)) +
  geom_sf(aes(fill = EQRS_3_Class)) +
  scale_fill_manual(name = "EQRS_3", values = EQRS_Class_colors, limits = EQRS_Class_limits, labels = EQRS_Class_labels)
ggsave(file.path(outputPath, "Assessment_Map_EQRS_3.png"), width = 12, height = 9, dpi = 300)

# Confidence maps
ggplot(wk) +
  ggtitle(label = paste0("Eutrophication Confidence ", assessmentPeriod)) +
  geom_sf(aes(fill = C_Class)) +
  scale_fill_manual(name = "C", values = C_Class_colors, limits = C_Class_limits, labels = C_Class_labels)
ggsave(file.path(outputPath, "Assessment_Map_C.png"), width = 12, height = 9, dpi = 300)

ggplot(wk) +
  ggtitle(label = paste0("Eutrophication Confidence ", assessmentPeriod)) +
  geom_sf(aes(fill = C_1_Class)) +
  scale_fill_manual(name = "C_1", values = C_Class_colors, limits = C_Class_limits, labels = C_Class_labels)
ggsave(file.path(outputPath, "Assessment_Map_C_1.png"), width = 12, height = 9, dpi = 300)

ggplot(wk) +
  ggtitle(label = paste0("Eutrophication Confidence ", assessmentPeriod)) +
  geom_sf(aes(fill = C_2_Class)) +
  scale_fill_manual(name = "C_2", values = C_Class_colors, limits = C_Class_limits, labels = C_Class_labels)
ggsave(file.path(outputPath, "Assessment_Map_C_2.png"), width = 12, height = 9, dpi = 300)

ggplot(wk) +
  ggtitle(label = paste0("Eutrophication Confidence ", assessmentPeriod)) +
  geom_sf(aes(fill = C_3_Class)) +
  scale_fill_manual(name = "C_3", values = C_Class_colors, limits = C_Class_limits, labels = C_Class_labels)
ggsave(file.path(outputPath, "Assessment_Map_C_3.png"), width = 12, height = 9, dpi = 300)

# Create Assessment Indicator maps
for (i in 1:nrow(indicators)) {
  indicatorID <- indicators[i, IndicatorID]
  indicatorCode <- indicators[i, Code]
  indicatorName <- indicators[i, Name]
  indicatorYearMin <- indicators[i, YearMin]
  indicatorYearMax <- indicators[i, YearMax]
  indicatorMonthMin <- indicators[i, MonthMin]
  indicatorMonthMax <- indicators[i, MonthMax]
  indicatorDepthMin <- indicators[i, DepthMin]
  indicatorDepthMax <- indicators[i, DepthMax]
  indicatorYearMin <- indicators[i, YearMin]
  indicatorMetric <- indicators[i, Metric]

  wk <- wk5[IndicatorID == indicatorID] %>% setkey(UnitID)
  
  wk <- merge(units, wk, by = "UnitID", all.x = TRUE)  
    
  # Status map (EQRS)
  title <- paste0("Eutrophication Status ", indicatorYearMin, "-", indicatorYearMax)
  subtitle <- paste0(indicatorName, " (", indicatorCode, ")", "\n")
  subtitle <- paste0(subtitle, "Months: ", indicatorMonthMin, "-", indicatorMonthMax, ", ")
  subtitle <- paste0(subtitle, "Depths: ", indicatorDepthMin, "-", indicatorDepthMax, ", ")
  subtitle <- paste0(subtitle, "Metric: ", indicatorMetric)
  fileName <- gsub(":", "", paste0("Assessment_Indicator_Map_", indicatorCode, "_EQRS", ".png"))
  
  ggplot(wk) +
    labs(title = title , subtitle = subtitle) +
    geom_sf(aes(fill = EQRS_Class)) +
    scale_fill_manual(name = "EQRS", values = EQRS_Class_colors, limits = EQRS_Class_limits, labels = EQRS_Class_labels)
  ggsave(file.path(outputPath, fileName), width = 12, height = 9, dpi = 300)

  # Temporal Confidence map (TC)
  title <- paste0("Eutrophication Temporal Confidence ", indicatorYearMin, "-", indicatorYearMax)
  subtitle <- paste0(indicatorName, " (", indicatorCode, ")", "\n")
  subtitle <- paste0(subtitle, "Months: ", indicatorMonthMin, "-", indicatorMonthMax, ", ")
  subtitle <- paste0(subtitle, "Depths: ", indicatorDepthMin, "-", indicatorDepthMax, ", ")
  subtitle <- paste0(subtitle, "Metric: ", indicatorMetric)
  fileName <- gsub(":", "", paste0("Assessment_Indicator_Map_", indicatorCode, "_TC", ".png"))
  
  ggplot(wk) +
    labs(title = title , subtitle = subtitle) +
    geom_sf(aes(fill = TC_Class)) +
    scale_fill_manual(name = "TC", values = C_Class_colors, limits = C_Class_limits, labels = C_Class_labels)
  ggsave(file.path(outputPath, fileName), width = 12, height = 9, dpi = 300)
  
  # Spatial Confidence map (SC)
  title <- paste0("Eutrophication Spatial Confidence ", indicatorYearMin, "-", indicatorYearMax)
  subtitle <- paste0(indicatorName, " (", indicatorCode, ")", "\n")
  subtitle <- paste0(subtitle, "Months: ", indicatorMonthMin, "-", indicatorMonthMax, ", ")
  subtitle <- paste0(subtitle, "Depths: ", indicatorDepthMin, "-", indicatorDepthMax, ", ")
  subtitle <- paste0(subtitle, "Metric: ", indicatorMetric)
  fileName <- gsub(":", "", paste0("Assessment_Indicator_Map_", indicatorCode, "_SC", ".png"))
  
  ggplot(wk) +
    labs(title = title , subtitle = subtitle) +
    geom_sf(aes(fill = SC_Class)) +
    scale_fill_manual(name = "SC", values = C_Class_colors, limits = C_Class_limits, labels = C_Class_labels)
  ggsave(file.path(outputPath, fileName), width = 12, height = 9, dpi = 300)
  
  # Accuracy Confidence Class map (ACC)
  title <- paste0("Eutrophication Accuracy Class Confidence ", indicatorYearMin, "-", indicatorYearMax)
  subtitle <- paste0(indicatorName, " (", indicatorCode, ")", "\n")
  subtitle <- paste0(subtitle, "Months: ", indicatorMonthMin, "-", indicatorMonthMax, ", ")
  subtitle <- paste0(subtitle, "Depths: ", indicatorDepthMin, "-", indicatorDepthMax, ", ")
  subtitle <- paste0(subtitle, "Metric: ", indicatorMetric)
  fileName <- gsub(":", "", paste0("Assessment_Indicator_Map_", indicatorCode, "_ACC", ".png"))
  
  ggplot(wk) +
    labs(title = title , subtitle = subtitle) +
    geom_sf(aes(fill = ACC_Class)) +
    scale_fill_manual(name = "ACC", values = C_Class_colors, limits = C_Class_limits, labels = C_Class_labels)
  ggsave(file.path(outputPath, fileName), width = 12, height = 9, dpi = 300)
  
  # Confidence map (C)
  title <- paste0("Eutrophication Confidence ", indicatorYearMin, "-", indicatorYearMax)
  subtitle <- paste0(indicatorName, " (", indicatorCode, ")", "\n")
  subtitle <- paste0(subtitle, "Months: ", indicatorMonthMin, "-", indicatorMonthMax, ", ")
  subtitle <- paste0(subtitle, "Depths: ", indicatorDepthMin, "-", indicatorDepthMax, ", ")
  subtitle <- paste0(subtitle, "Metric: ", indicatorMetric)
  fileName <- gsub(":", "", paste0("Assessment_Indicator_Map_", indicatorCode, "_C", ".png"))
  
  ggplot(wk) +
    labs(title = title , subtitle = subtitle) +
    geom_sf(aes(fill = C_Class)) +
    scale_fill_manual(name = "C", values = C_Class_colors, limits = C_Class_limits, labels = C_Class_labels)
  ggsave(file.path(outputPath, fileName), width = 12, height = 9, dpi = 300)
}

# Create Annual Indicator bar charts
for (i in 1:nrow(indicators)) {
  indicatorID <- indicators[i, IndicatorID]
  indicatorCode <- indicators[i, Code]
  indicatorName <- indicators[i, Name]
  indicatorUnit <- indicators[i, Units]
  indicatorYearMin <- indicators[i, YearMin]
  indicatorYearMax <- indicators[i, YearMax]
  indicatorMonthMin <- indicators[i, MonthMin]
  indicatorMonthMax <- indicators[i, MonthMax]
  indicatorDepthMin <- indicators[i, DepthMin]
  indicatorDepthMax <- indicators[i, DepthMax]
  indicatorYearMin <- indicators[i, YearMin]
  indicatorMetric <- indicators[i, Metric]
  for (j in 1:nrow(units)) {
    unitID <- as.data.table(units)[j, UnitID]
    unitCode <- as.data.table(units)[j, Code]
    unitName <- as.data.table(units)[j, Description]
    
    title <- paste0("Eutrophication State [ES, CI, N] and Threshold [ET] ", indicatorYearMin, "-", indicatorYearMax)
    subtitle <- paste0(indicatorName, " (", indicatorCode, ")", " in ", unitName, " (", unitCode, ")", "\n")
    subtitle <- paste0(subtitle, "Months: ", indicatorMonthMin, "-", indicatorMonthMax, ", ")
    subtitle <- paste0(subtitle, "Depths: ", indicatorDepthMin, "-", indicatorDepthMax, ", ")
    subtitle <- paste0(subtitle, "Metric: ", indicatorMetric, ", ")
    subtitle <- paste0(subtitle, "Unit: ", indicatorUnit)
    fileName <- gsub(":", "", paste0("Annual_Indicator_Bar_", indicatorCode, "_", unitCode, ".png"))
    
    wk <- wk3[IndicatorID == indicatorID & UnitID == unitID]
    
    if (nrow(wk) > 0) {
      ggplot(wk, aes(x = factor(Period, levels = indicatorYearMin:indicatorYearMax), y = ES)) +
        labs(title = title , subtitle = subtitle) +
        geom_col() +
        geom_text(aes(label = N), vjust = -0.25, hjust = -0.25) +
        geom_errorbar(aes(ymin = ES - CI, ymax = ES + CI), width = .2) +
        geom_hline(aes(yintercept = ET)) +
        scale_x_discrete(NULL, factor(indicatorYearMin:indicatorYearMax), drop=FALSE) +
        scale_y_continuous(NULL)
      
      ggsave(file.path(outputPath, fileName), width = 12, height = 9, dpi = 300)
    }
  }
}

