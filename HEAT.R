# Install and load R packages ---------------------------------------------
# 
# Check to see if packages are installed. Install them if they are not, then load them into the R session.
ipak <- function(pkg){
  new.pkg <- pkg[!(pkg %in% installed.packages()[, "Package"])]
  if (length(new.pkg)) 
    install.packages(new.pkg, dependencies = TRUE)
  sapply(pkg, require, character.only = TRUE)
}
packages <- c("sf", "data.table", "ggplot2", "tidyverse")
ipak(packages)

# ES = Eutrophication Status
# SD = Standard Deviation
# N = Number of Observations
# N_Min = Minimum Number of Observations any given year 
# SE = Standards Error
# CI = Confidense Interval 95 %
# ER = Eutrophication Ratio
# BEST
# EQR = Ecological Quality Ratio
# EQR_HG
# EQR_GM
# EQR_MP
# EQR_PB
# EQRS = Ecological Quality Ratio Scaled
# TCG
# TCS
# TC
# SCG
# SCS
# SC
# IW

# Links to Unit, Data and Config files ----------------------------------------- 
#unitsFile <- "https://www.dropbox.com/s/tpzirhsr11yuwb4/AssessmentUnit_20112016.zip"
#stationSamplesFile <- "https://www.dropbox.com/s/ehbb50myea9ebx8/StationSamplesICE.zip"
#indicatorFile <- "https://www.dropbox.com/s/3vw8uhxseyk24yo/Indicator.txt"
#indicatorUnitFile <- "https://www.dropbox.com/s/iiqfjsg6fvyx5ux/IndicatorUnit.txt"

unitsFile <- "assessment/20112016/AssessmentUnit_20112016.zip"
stationSamplesFile <- "assessment/20112016/StationSamplesICE.zip"
indicatorFile <- "assessment/20112016/Indicator.txt"
indicatorUnitFile <- "assessment/20112016/IndicatorUnit.txt"

indicator <- fread(input = indicatorFile, sep = "\t")
indicatorUnit <- fread(input = indicatorUnitFile, sep = "\t")

# Assessment Units -------------------------------------------------------------

# Read assessment unit from shapefile
units <- st_read(unitsFile)

# Filter for open sea assessment units
units <- units[units$Code %like% 'SEA',]

# Include stations from position 55.86667+-0.01667 12.75+-0.01667 which will include the Danish station KBH/DMU 431 and the Swedish station Wlandskrona into assessment unit 3/SEA-003
units[3,] <- st_union(units[3,],st_as_sfc("POLYGON((12.73333 55.85,12.73333 55.88334,12.76667 55.88334,12.76667 55.85,12.73333 55.85))", crs = 4326))
#units[units$Code == 'SEA-003',] <- st_union(units[units$Code == 'SEA-003',],st_as_sfc("POLYGON((12.73333 55.85,12.73333 55.88334,12.76667 55.88334,12.76667 55.85,12.73333 55.85))", crs = 4326))

# Convert to data.table
#units <- as.data.table(units)

# Assign IDs
units$UnitID = 1:nrow(units)

# Identify invalid geometries
st_is_valid(units)

# Transform projection into ETRS_1989_LAEA
units <- st_transform(units, crs = 3035)

# Calculate area
units$UnitArea <- st_area(units)

#setDT(units)
#setkey(units, UnitID)

# Identify invalid geometries
st_is_valid(units)

# Make geometries valid by doing the buffer of nothing trick
#units <- sf::st_buffer(units, 0.0)

# Identify overlapping assessment units
#st_overlaps(units)

# Make grid units
make_gridunits <- function(units, gridSize)
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
  
  #setDT(gridunits)
  
  #gridunits <- gridunits[order(GridID, UnitID),.(GridID, UnitID, Area, geometry)]

  return(gridunits)
}

gridunits10 <- make_gridunits(units, 10000)

gridunits30 <- make_gridunits(units, 30000)

# Plot
ggplot() + geom_sf(data = units) + coord_sf()
ggplot() + geom_sf(data = gridunits10) + coord_sf()
ggplot() + geom_sf(data = gridunits30) + coord_sf()

# Read stationSamples ----------------------------------------------------------
stationSamples <- fread(input = stationSamplesFile, sep = "\t", na.strings = "NULL", stringsAsFactors = FALSE, header = TRUE, check.names = TRUE)

# !!! We could separate stations from samples here, do the spatial and then rejoin samples again ... migth be more rubust

# Make stations spatial keeping original latitude/longitude
stationSamples <- st_as_sf(stationSamples, coords = c("Longitude..degrees_east.", "Latitude..degrees_north."), remove = FALSE, crs = 4326)

# Transform projection into ETRS_1989_LAEA
stationSamples <- st_transform(stationSamples, crs = 3035)

# Classify stations into assessment units
stationSamples$UnitID <- st_intersects(stationSamples, units) %>% as.numeric()

# Classify stations into 10k gridunits
#stations <- st_intersection(stations, gridunits10 %>% select(GridID.10k = GridID, Area.10k = Area))
stationSamples <- st_join(stationSamples, gridunits10 %>% select(GridID.10k = GridID, Area.10k = Area), join = st_intersects)

# Classify stations into 30k gridunits
stationSamples <- st_join(stationSamples, gridunits30 %>% select(GridID.30k = GridID, Area.30k = Area), join = st_intersects)

# Remove spatial column
stationSamples <- st_set_geometry(stationSamples, NULL)

# Read indicator configs
indicator <- fread(input = indicatorFile, sep = "\t") %>% setnames("ID", "IndicatorID") %>% setkey(IndicatorID) 
indicatorUnit <- fread(input = indicatorUnitFile, sep = "\t") %>% setkey(IndicatorID, UnitID)

# Dissolved inorganic Nitrogen - DIN (Winter) ----------------------------------
#   Parameters: [NO3-N] + [NO2-N] + [NH4-N]
#   Depth: <= 10
#   Period: December - February
#   Aggregation Method: Arithmetric mean of mean by station per year

# Copy data
wk <- as.data.table(stationSamples)

# Count unique stations
wk[,.(count = uniqueN(StationID))]

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
wk$DIN..umol.l. <- apply(wk[, list(Nitrate..umol.l., Nitrite..umol.l., Ammonium..umol.l.)], 1, coalesce)

# Filter stations rows and columns --> UnitID, GridID, GridArea, Period, Month, Depth, ES
wk0 <- wk[Depth..m.db..PRIMARYVAR.DOUBLE <= 10 & (Month >= 12 | Month <= 2) & (Period >= 2011 & Period <= 2016) & !is.na(DIN..umol.l.), .(IndicatorID = 1, UnitID, GridID = ifelse(UnitID == 3, GridID.10k, GridID.30k), GridArea = ifelse(UnitID == 3, Area.10k, Area.30k), Period, Month, StationID, Depth = Depth..m.db..PRIMARYVAR.DOUBLE, ES = DIN..umol.l.)]

# Calculate station mean --> UnitID, GridID, GridArea, Period, Month, ES, SD, N
wk1 <- wk0[, .(ES = mean(ES), SD = sd(ES), N = .N), keyby = .(IndicatorID, UnitID, GridID, GridArea,Period, Month, StationID)]

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
wk4 <- wk2[, .(Period = min(Period) * 10000 + max(Period), ES = mean(ES), SD = sd(ES), N = .N, N_MIN = min(N), NM = sum(NM), NS = sum(N)), .(IndicatorID, UnitID)]

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
wk5[, GTC := ifelse(N_MIN > GTC_HM, 100, ifelse(N_MIN < GTC_ML, 0, 50))]

# Calculate Specific temporal confidence (STC) - number of missing months in assessment period
# !!! 18 month hardcoded for now which need to be change dynamically in config table to indicator years and months
wk5[, STC := ifelse(18 - NM <= STC_HM, 100, ifelse(18 - NM > STC_ML, 0, 50))]

# Calculate Total Temporal Confidence (TTC)
wk5[, TTC := (GTC + STC) / 2]

# Calculate General spatial confidence (GSC) - number of annual observations per grid cell ... and then what? annual average?

# Calculate Specific spatial confidence (SSC) - area of sampled grid unit cells as a procentage to total unit area
a <- wk1[, .N, keyby = .(IndicatorID, UnitID, GridID, GridArea)]
b <- a[, .(GridArea = sum(as.numeric(GridArea))), keyby = .(IndicatorID, UnitID)]
c <- as.data.table(units)[, .(UnitArea = as.numeric(UnitArea)), keyby = .(UnitID)]
d <- c[b, on = .(UnitID = UnitID)]
wk5 <- wk5[d[,.(UnitID, UnitArea, GridArea)], on = .(UnitID = UnitID)]
wk5[, SSC := ifelse(GridArea / UnitArea * 100 > SSC_HM, 100, ifelse(GridArea / UnitArea * 100 < SSC_ML, 0, 50))]
rm(a,b,c,d)

# Calculate Total Confidence (TC)
wk5[, TC := (TTC + SSC) / 2]

# Write result to files
fwrite(wk3, file = "assessment/20112016/Annual.csv")
fwrite(wk5, file = "assessment/20112016/Assessment.csv")
