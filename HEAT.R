# Install and load R packages ---------------------------------------------
# 
# Check to see if packages are installed. Install them if they are not, then load them into the R session.
ipak <- function(pkg){
  new.pkg <- pkg[!(pkg %in% installed.packages()[, "Package"])]
  if (length(new.pkg)) 
    install.packages(new.pkg, dependencies = TRUE)
  sapply(pkg, require, character.only = TRUE)
}
packages <- c("sf", "data.table", "ggplot2", "tidyverse", "mapview")
ipak(packages)

# Util functions ---------------------------------------------------------------
download.file.unzip.maybe <- function(url, refetch = FALSE, path = ".") {
  dest <- file.path(path, sub("\\?.+", "", basename(url)))
  if (refetch || !file.exists(dest)) {
    download.file(url, dest, mode = "wb")
    if (tools::file_ext(dest) == "zip") {
      unzip(dest, exdir = path)
    }
  }
}

make.gridunits <- function(units, gridSize)
{
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

# Download and unpack files needed for the assessment --------------------------
urls <- c("https://www.dropbox.com/s/s79psj46ua61dao/AssessmentUnits_20112016.zip?dl=1",
           "https://www.dropbox.com/s/7wahao1dwcvese9/Indicators.txt?dl=1",
           "https://www.dropbox.com/s/5lcv5j5a4wabn7p/IndicatorUnits.txt?dl=1",
           "https://www.dropbox.com/s/ehbb50myea9ebx8/StationSamplesICE.zip?dl=1",
           "https://www.dropbox.com/s/qjgx0b5plkwz6iv/StationSamplesCTD.zip?dl=1")

assessment <- "20112016"
path <- paste0("Assessment/", assessment)
dir.create(path, showWarnings = FALSE, recursive = TRUE)
files <- sapply(urls, download.file.unzip.maybe, path = path)

assessmentUnitsFile <- file.path(path, paste0("AssessmentUnits_", assessment, ".shp"))
indicatorsFile <- file.path(path, "Indicators.txt")
indicatorUnitsFile <- file.path(path, "IndicatorUnits.txt")
stationSamplesICEFile <- file.path(path, "StationSamplesICE.txt")

# Assessment Units + Grid Units-------------------------------------------------

# Read assessment unit from shapefile
units <- st_read(assessmentUnitsFile)

# Filter for open sea assessment units
units <- units[units$Code %like% 'SEA',]

# Include stations from position 55.86667+-0.01667 12.75+-0.01667 which will include the Danish station KBH/DMU 431 and the Swedish station Wlandskrona into assessment unit 3/SEA-003
units[3,] <- st_union(units[3,],st_as_sfc("POLYGON((12.73333 55.85,12.73333 55.88334,12.76667 55.88334,12.76667 55.85,12.73333 55.85))", crs = 4326))
#units[units$Code == 'SEA-003',] <- st_union(units[units$Code == 'SEA-003',],st_as_sfc("POLYGON((12.73333 55.85,12.73333 55.88334,12.76667 55.88334,12.76667 55.85,12.73333 55.85))", crs = 4326))

# Convert to data.table
#units <- as.data.table(units) %>% st_sf()

# Assign IDs
units$UnitID = 1:nrow(units)

# Identify invalid geometries
st_is_valid(units)

# Transform projection into ETRS_1989_LAEA
units <- st_transform(units, crs = 3035)

# Calculate area
units$UnitArea <- st_area(units)

# Identify invalid geometries
st_is_valid(units)

# Make geometries valid by doing the buffer of nothing trick
#units <- sf::st_buffer(units, 0.0)

# Identify overlapping assessment units
#st_overlaps(units)

# Make grid units
gridunits10 <- make.gridunits(units, 10000)

gridunits30 <- make.gridunits(units, 30000)

# Plot
#ggplot() + geom_sf(data = units) + coord_sf()
#ggplot() + geom_sf(data = gridunits10) + coord_sf()
#ggplot() + geom_sf(data = gridunits30) + coord_sf()

# Read stationSamples ----------------------------------------------------------
stationSamples <- fread(input = stationSamplesICEFile, sep = "\t", na.strings = "NULL", stringsAsFactors = FALSE, header = TRUE, check.names = TRUE)

# !!! We could separate stations from samples here, do the spatial and then rejoin samples again ... migth be more rubust
#stationSamples[, StationID := .GRP, by = .(Cruise, StationNumber, Year, Month, Day, Hour, Minute, Latitude..degrees_north., Longitude..degrees_east.)]
#stationSamples[, .N, .(ID, Cruise, StationNumber, Year, Month, Day, Hour, Minute, Latitude..degrees_north., Longitude..degrees_east.)]

# Make stations spatial keeping original latitude/longitude
stationSamples <- st_as_sf(stationSamples, coords = c("Longitude..degrees_east.", "Latitude..degrees_north."), remove = FALSE, crs = 4326)

# Transform projection into ETRS_1989_LAEA
stationSamples <- st_transform(stationSamples, crs = 3035)

# Classify stations into assessment units
stationSamples$UnitID <- st_intersects(stationSamples, units) %>% as.numeric()

# Classify stations into 10k gridunits
stationSamples <- st_join(stationSamples, gridunits10 %>% select(GridID.10k = GridID, Area.10k = Area), join = st_intersects)

# Classify stations into 30k gridunits
stationSamples <- st_join(stationSamples, gridunits30 %>% select(GridID.30k = GridID, Area.30k = Area), join = st_intersects)

# Remove spatial column
stationSamples <- st_set_geometry(stationSamples, NULL)

# Read indicator configs -------------------------------------------------------
indicators <- fread(input = indicatorsFile, sep = "\t") %>% setkey(IndicatorID) 
indicatorUnits <- fread(input = indicatorUnitsFile, sep = "\t") %>% setkey(IndicatorID, UnitID)

# Loop indicator units ---------------------------------------------------------
for (i in 1:nrow(indicatorUnits)) {
  indicatorID <- indicatorUnits[i, IndicatorID]
  
  
  
}

# Loop indicators --------------------------------------------------------------
for(i in 1:nrow(indicators)){
  indicatorID <- indicators[i, IndicatorID]
  criteriaID <- indicators[i, CriteriaID]
  categoryID <- 0
  year.min <- indicators[i, YearMin]
  year.max <- indicators[i, YearMax]
  month.min <- indicators[i, MonthMin]
  month.max <- indicators[i, MonthMax]
  depth.min <- indicators[i, DepthMin]
  depth.max <- indicators[i, DepthMax]

  # Copy data
  wk <- as.data.table(stationSamples)

  # Create Period
  wk[, Period := ifelse(month.min > month.max & Month >= month.min, Year + 1, Year)]

  # Create Indicator
  if (indicatorID == 1) { # Dissolved Inorganic Nitrogen
    wk$ES <- apply(wk[, list(Nitrate..umol.l., Nitrite..umol.l., Ammonium..umol.l.)], 1, function(x){
      if (all(is.na(x)) | is.na(x[1])) {
        NA
      }
      else {
        sum(x, na.rm = TRUE)
      }
    })
  }
  else if (indicatorID == 2) { # Dissolved Inorganic Phosphorus
    wk[,ES := Phosphate..umol.l.]
  }
  else if (indicatorID == 3) { # Cholorophyll a
    wk[, ES := Chlorophyll.a..ug.l.]
  }

  # Filter stations rows and columns --> UnitID, GridID, GridArea, Period, Month, StationID, Depth, ES
  if (month.min > month.max) {
    wk0 <- wk[
        (Period >= year.min & Period <= year.max) &
        (Month >= month.min | Month <= month.max) &
        (Depth..m.db..PRIMARYVAR.DOUBLE >= depth.min & Depth..m.db..PRIMARYVAR.DOUBLE <= depth.max) &
        !is.na(ES) & 
        !is.na(UnitID),
        .(IndicatorID = indicatorID, UnitID, GridID = ifelse(UnitID == 3, GridID.10k, GridID.30k), GridArea = ifelse(UnitID == 3, Area.10k, Area.30k), Period, Month, StationID, Depth = Depth..m.db..PRIMARYVAR.DOUBLE, ES)]
  } else {
    wk0 <- wk[(Period >= year.min & Period <= year.max) &
                (Month >= month.min & Month <= month.max) &
                (Depth..m.db..PRIMARYVAR.DOUBLE >= depth.min & Depth..m.db..PRIMARYVAR.DOUBLE <= depth.max) &
                !is.na(ES) & 
                !is.na(UnitID),
              .(IndicatorID = indicatorID, UnitID, GridID = ifelse(UnitID == 3, GridID.10k, GridID.30k), GridArea = ifelse(UnitID == 3, Area.10k, Area.30k), Period, Month, StationID, Depth = Depth..m.db..PRIMARYVAR.DOUBLE, ES)]
  }


}

# Dissolved inorganic Nitrogen - DIN (Winter) ----------------------------------
#   Parameters: [NO3-N] + [NO2-N] + [NH4-N]
#   Depth: <= 10
#   Period: December - February
#   Aggregation Method: Arithmetric mean of mean by station per year

# Copy data
wk <- as.data.table(stationSamples)

# Create grouping variable
wk$Period <- with(wk, ifelse(Month == 12, Year + 1, Year))

# Create indicator
coalesce <- function(x) {
  if (all(is.na(x)) | is.na(x[1])){
    NA
  } else {
    sum(x, na.rm = TRUE)
  } 
}
wk$ES <- apply(wk[, list(Nitrate..umol.l., Nitrite..umol.l., Ammonium..umol.l.)], 1, coalesce)

# Filter stations rows and columns --> UnitID, GridID, GridArea, Period, Month, StationID, Depth, ES
wk0 <- wk[(Period >= 2011 & Period <= 2016) & (Month >= 12 | Month <= 2) & Depth..m.db..PRIMARYVAR.DOUBLE <= 10 & !is.na(ES) & !is.na(UnitID), .(IndicatorID = 1, UnitID, GridID = ifelse(UnitID == 3, GridID.10k, GridID.30k), GridArea = ifelse(UnitID == 3, Area.10k, Area.30k), Period, Month, StationID, Depth = Depth..m.db..PRIMARYVAR.DOUBLE, ES)]

# Calculate station mean --> UnitID, GridID, GridArea, Period, Month, ES, SD, N
wk1 <- wk0[, .(ES = mean(ES), SD = sd(ES), N = .N), keyby = .(IndicatorID, UnitID, GridID, GridArea, Period, Month, StationID)]

# Calculate annual mean --> UnitID, Period, ES, SD, N, NM
wk2 <- wk1[, .(ES = mean(ES), SD = sd(ES), N = .N, NM = uniqueN(Month)), keyby = .(IndicatorID, UnitID, Period)]

# Combine with indicator and indicator unit configuration tables
wk3 <- indicator[indicatorUnit[wk2]]

# Calculate Eutrophication Ratio (ER)
wk3[, ER := ifelse(Response == 1, ES/ET, ET/ES)]

# Calculate Ecological Quality Ratio (ERQ)
wk3[, EQR := ifelse(Response == 1, BEST/ES, ES/BEST)]

# Calculate Ecological Quality Ratio Scaled (EQRS)
wk3[, EQRS := ifelse(EQR <= EQR_PB, (EQR - 0) * (0.2 - 0) / (EQR_PB - 0) + 0,
                      ifelse(EQR <= EQR_MP, (EQR - EQR_PB) * (0.4 - 0.2) / (EQR_MP - EQR_PB) + 0.2,
                             ifelse(EQR <= EQR_GM, (EQR - EQR_MP) * (0.6 - 0.4) / (EQR_GM - EQR_MP) + 0.4,
                                    ifelse(EQR <= EQR_HG, (EQR - EQR_GM) * (0.8 - 0.6) / (EQR_HG - EQR_GM) + 0.6,
                                           (EQR - EQR_HG) * (1 - 0.8) / (1 - EQR_HG) + 0.8))))]

# Calculate General Temporal Confidence (GTC) - number of annual observations
wk3[, GTC := ifelse(N > GTC_HM, 100, ifelse(N < GTC_ML, 0, 50))]

# Calculate Specific Temporal Confidence (STC) - number of annual missing months
# !!! 3 month hardcoded for now which need to be change dynamically in config table to indicator months
wk3[, STC := ifelse(3 - NM <= STCA_HM, 100, ifelse(3 -NM > STCA_ML, 0, 50))]

# Calculate Total Temporal Confidence (TTC)
wk3[, TTC := (GTC + STC) / 2]

# Calculate General Spatial Confidence (GSC) - number of annual observations per grid cell ... and then what? annual average?

# Calculate Specific Spatial Confidence (SSC) - area of sampled grid unit cells as a procentage to total unit area
a <- wk1[, .N, keyby = .(IndicatorID, UnitID, Period, GridID, GridArea)]
b <- a[, .(GridArea = sum(as.numeric(GridArea))), keyby = .(IndicatorID, UnitID, Period)]
c <- as.data.table(units)[, .(UnitArea = as.numeric(UnitArea)), keyby = .(UnitID)]
d <- c[b, on = .(UnitID = UnitID)]
wk3 <- wk3[d[,.(UnitID, Period, UnitArea, GridArea)], on = .(UnitID = UnitID, Period = Period)]
wk3[, SSC := ifelse(GridArea / UnitArea * 100 > SSC_HM, 100, ifelse(GridArea / UnitArea * 100 < SSC_ML, 0, 50))]
rm(a,b,c,d)

# Calculate Total Confidence (TC)
wk3[, TC := (TTC + SSC) / 2]

# Calculate assessment ES --> UnitID, Period, ES, SD, N, N_MIN, NM, NS
#wk4 <- wk2[, .(Period = min(Period) * 10000 + max(Period), ES = mean(ES), SD = sd(ES), N = .N, N_MIN = min(N), NM = sum(NM), NS = sum(N)), .(IndicatorID, UnitID)]
wk4 <- wk3[, .(Period = min(Period) * 10000 + max(Period), ES = mean(ES), SD = sd(ES), N = .N, N_MIN = min(N), NM = sum(NM), NS = sum(N), GTC = mean(GTC), STC = mean(STC), SSC = mean(SSC)), .(IndicatorID, UnitID)]
#wk4 <- wk3[, .(Period = min(Period) * 10000 + max(Period), ES = mean(ES), ES_SD = sd(ES), ES_N = .N, N_MIN = min(N), NM = sum(NM), NS = sum(N), ER = mean(ER), EQR = mean(EQR), EQRS = mean(EQRS), GTC = mean(GTC), STC = mean(STC), SSC = mean(SSC)), .(IndicatorID, UnitID)]

# Combine with indicator and indicator unit configuration tables
wk5 <- indicator[indicatorUnit[wk4]]

# Standard Error
wk5[, SE := SD / sqrt(N)]

# 95 % Confidence Interval
wk5[, CI := qnorm(0.975) * SE]

# Calculate Eutrophication Ratio (ER)
wk5[, ER := ifelse(Response == 1, ES/ET, ET/ES)]

# Calculate Ecological Quality Ratio (ERQ)
wk5[, EQR := ifelse(Response == 1, BEST/ES, ES/BEST)]

# Calculate Ecological Quality Ratio Scaled (EQRS)
wk5[, EQRS := ifelse(EQR <= EQR_PB, (EQR - 0) * (0.2 - 0) / (EQR_PB - 0) + 0,
                     ifelse(EQR <= EQR_MP, (EQR - EQR_PB) * (0.4 - 0.2) / (EQR_MP - EQR_PB) + 0.2,
                            ifelse(EQR <= EQR_GM, (EQR - EQR_MP) * (0.6 - 0.4) / (EQR_GM - EQR_MP) + 0.4,
                                   ifelse(EQR <= EQR_HG, (EQR - EQR_GM) * (0.8 - 0.6) / (EQR_HG - EQR_GM) + 0.6,
                                          (EQR - EQR_HG) * (1 - 0.8) / (1 - EQR_HG) + 0.8))))]

# Calculate General temporal confidence (GTC) - minimum number of annual observations
#wk5[, GTC := ifelse(N_MIN > GTC_HM, 100, ifelse(N_MIN < GTC_ML, 0, 50))]

# Calculate Specific temporal confidence (STC) - number of missing months in assessment period
# !!! 18 month hardcoded for now which need to be change dynamically in config table to indicator years and months
wk5[, STCX := ifelse(18 - NM <= STC_HM, 100, ifelse(18 - NM > STC_ML, 0, 50))]

# Calculate Total Temporal Confidence (TTC)
wk5[, TTC := (GTC + STC) / 2]

# Calculate General spatial confidence (GSC) - number of annual observations per grid cell ... and then what? annual average?

# Calculate Specific spatial confidence (SSC) - area of sampled grid unit cells as a procentage to total unit area
#a <- wk1[, .N, keyby = .(IndicatorID, UnitID, GridID, GridArea)]
#b <- a[, .(GridArea = sum(as.numeric(GridArea))), keyby = .(IndicatorID, UnitID)]
#c <- as.data.table(units)[, .(UnitArea = as.numeric(UnitArea)), keyby = .(UnitID)]
#d <- c[b, on = .(UnitID = UnitID)]
#wk5 <- wk5[d[,.(UnitID, UnitArea, GridArea)], on = .(UnitID = UnitID)]
#wk5[, SSC := ifelse(GridArea / UnitArea * 100 > SSC_HM, 100, ifelse(GridArea / UnitArea * 100 < SSC_ML, 0, 50))]
#rm(a,b,c,d)

# Calculate Total Confidence (TC)
wk5[, TC := (TTC + SSC) / 2]

# Write result to files
fwrite(wk3, file = "assessment/20112016/Annual_20200520.csv")
fwrite(wk5, file = "assessment/20112016/Assessment_20200520.csv")

# Dissolved inorganic Phosphorus - DIP (Winter) --------------------------------
#   Parameters: [PO4-P]
#   Depth: <= 10
#   Period: December - February
#   Aggregation Method: Arithmetric mean of mean by station per year

wk <- as.data.table(stationSamples)

# Create grouping variable
wk$Period <- with(wk, ifelse(Month == 12, Year + 1, Year))

# Filter stations rows and columns --> UnitID, GridID, GridArea, Period, Month, Depth, ES
wk0 <- wk[Depth..m.db..PRIMARYVAR.DOUBLE <= 10 & (Month >= 12 | Month <= 2) & (Period >= 2011 & Period <= 2016) & !is.na(Phosphate..umol.l.), .(IndicatorID = 2, UnitID, GridID = ifelse(UnitID == 3, GridID.10k, GridID.30k), GridArea = ifelse(UnitID == 3, Area.10k, Area.30k), Period, Month, StationID, Depth = Depth..m.db..PRIMARYVAR.DOUBLE, ES = Phosphate..umol.l.)]

mapview(list(st_geometry(units),st_geometry(stationSamples)))
