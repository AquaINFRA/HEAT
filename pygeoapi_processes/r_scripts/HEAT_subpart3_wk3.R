
# Import packages
library(readr)      # to get "read_delim"
library(sf)         # to get "st_read", %>%"
library(data.table) # to get "setkey", "fread", fwrite


#################
### Arguments ###
#################

args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_relevantStationSamplesPath = args[1]         # file, format: csv
in_combined_Chlorophylla_IsWeighted = args[2]   # string
in_unitsCleanedFilePath = args[3]               # file, format: shp
in_indicatorsPath = args[4]                     # file, format: csv
in_indicatorUnitsPath = args[5]                 # file, format: csv
in_indicatorUnitResultsPath = args[6]           # file, format: csv
out_AnnualIndicatorPath = args[7]               # file, format: csv. Full path to: AnnualIndicators.csv

# User params
# Flag to determine if the combined chlorophyll a in-situ/satellite indicator is
# a simple mean or a weighted mean based on confidence measures
if (in_combined_Chlorophylla_IsWeighted == 'true') {
  in_combined_Chlorophylla_IsWeighted <- TRUE
} else {
  in_combined_Chlorophylla_IsWeighted <- FALSE
}

# How to run this in bash:
#in_relevantStationSamplesPath="/home/work/testoutputs/StationSamples.csv"
#in_combined_Chlorophylla_IsWeighted="true"
#in_unitsCleanedFilePath="/home/work/testoutputs/units_cleaned.shp"
#in_indicatorsPath="/home/work/inputs/2011-2016/Configuration2011-2016_Indicators.csv"
#in_indicatorUnitsPath="/home/work/inputs/2011-2016/Configuration2011-2016_IndicatorUnits.csv"
#in_indicatorUnitResultsPath="/home/work/inputs/2011-2016/Configuration2011-2016_IndicatorUnitResults.csv"
#out_AnnualIndicatorPath="/home/work/testoutputs/AnnualIndicators.csv"
#Rscript --vanilla HEAT_subpart3_wk3.R $in_relevantStationSamplesPath $in_combined_Chlorophylla_IsWeighted $in_unitsCleanedFilePath $in_indicatorsPath $in_indicatorUnitsPath $in_indicatorUnitResultsPath $out_AnnualIndicatorPath


###################
### Read inputs ###
###################

# Load required intermediate file:
print(paste('Now reading intermediate file from:', in_relevantStationSamplesPath))
stationSamples <- data.table::fread(in_relevantStationSamplesPath)
print(paste('Now reading intermediate file from:', in_unitsCleanedFilePath))
units <- sf::st_read(in_unitsCleanedFilePath)


# Correct column name:
if (! "UnitArea" %in% names(units)) {
  if ("UnitAre" %in% names(units)) {
    colnames(units)[colnames(units)=="UnitAre"] <- "UnitArea"
  } else {
    print('Missing column UnitArea or UnitAre in units...')
    stop()
  }
}

# Read indicator configs -------------------------------------------------------
print(paste('Reading indicators from', in_indicatorsPath))
indicators = as.data.table(readr::read_delim(in_indicatorsPath, delim=";", col_types = "iicccciiiinncnncnnnnnn")) %>% setkey(IndicatorID)
print(paste('Reading indicator units from', in_indicatorUnitsPath))
indicatorUnits = as.data.table(readr::read_delim(in_indicatorUnitsPath, delim=";", col_types = "iinnnnn")) %>% setkey(IndicatorID, UnitID)
print(paste('Reading indicator unit results from', in_indicatorUnitResultsPath))
indicatorUnitResults = as.data.table(readr::read_delim(in_indicatorUnitResultsPath, delim=";", col_types = "iiinninnnnnn")) %>% setkey(IndicatorID, UnitID, Period)




#####################
### Computing wk2 ###
#####################

wk2list = list()

print('Looping indicators...')
format(Sys.time(), "%Y-%m-%d %H:%M:%S")
# Loop indicators --------------------------------------------------------------
for(i in 1:nrow(indicators[IndicatorID < 1000,])){
  indicatorID <- indicators[i, IndicatorID]
  criteriaID <- indicators[i, CriteriaID]
  name <- indicators[i, Name]
  print(paste('Loop', i, name))
  year.min <- indicators[i, YearMin]
  year.max <- indicators[i, YearMax]
  month.min <- indicators[i, MonthMin]
  month.max <- indicators[i, MonthMax]
  depth.min <- indicators[i, DepthMin]
  depth.max <- indicators[i, DepthMax]
  metric <- indicators[i, Metric]
  response <- indicators[i, Response]

  # Copy data
  #stationSamples = readRDS(file = "my_stationSamples.rds")
  if (name == 'Chlorophyll a (FB)') {
    wk <- as.data.table(stationSamples[Type == 'P'])     
  } else {
    wk <- as.data.table(stationSamples[Type != 'P'])     
  }
  
  # Create Period
  wk[, Period := ifelse(month.min > month.max & Month >= month.min, Year + 1, Year)]
  
  # Create Indicator
  # For each indicator name, fill the columns ES and ESQ:
  if (name == 'Dissolved Inorganic Nitrogen') {
    wk$ES <- apply(wk[, list(Nitrate.Nitrogen..NO3.N...umol.l., Nitrite.Nitrogen..NO2.N...umol.l., Ammonium.Nitrogen..NH4.N...umol.l.)], 1, function(x) {
      if (all(is.na(x)) | is.na(x[1])) {
        NA
      } else {
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
    next # like "continue" in Python
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
# End of Loop indicators --------------------------------------------------------------
print('Looping indicators... done.')
print('TODO / FIXME: Here there were 50 or more warnings, right?')
format(Sys.time(), "%Y-%m-%d %H:%M:%S")

# HERE:
# There were 50 or more warnings (use warnings() to see the first 50)
# FIXME

# Combine annual indicator results
wk2 <- rbindlist(wk2list)

# Combine with indicator results reported
print('Combining with reported indicator results...')
wk2 <- rbindlist(list(wk2, indicatorUnitResults), fill = TRUE) # requires "data.table"

print('Start wk3')

# Combine with indicator and indicator unit configuration tables
wk3 <- indicators[indicatorUnits[wk2]]

# Calculate General Temporal Confidence (GTC) - Confidence in number of annual observations
print('Calculating GTC...')
wk3[is.na(GTC), GTC := ifelse(N > GTC_HM, 100, ifelse(N < GTC_ML, 0, 50))]

print('wk3 1')

# Calculate Number of Months Potential
wk3[, NMP := ifelse(MonthMin > MonthMax, 12 - MonthMin + 1 + MonthMax, MonthMax - MonthMin + 1)]

# Calculate Specific Temporal Confidence (STC) - Confidence in number of annual missing months
print('Calculating STC')
wk3[is.na(STC), STC := ifelse(NMP - NM <= STC_HM, 100, ifelse(NMP - NM >= STC_ML, 0, 50))]

print('wk3 2')

# Calculate General Spatial Confidence (GSC) - Confidence in number of annual observations per number of grids
# This was already disabled in original, see: https://github.com/ices-tools-prod/HEAT/blob/master/HEAT.R#L370
#wk3 <- wk3[as.data.table(gridunits)[, .(NG = as.numeric(sum(GridArea) / mean(GridSize^2))), .(UnitID)], on = .(UnitID = UnitID), nomatch=0]
#wk3[, GSC := ifelse(N / NG > GSC_HM, 100, ifelse(N / NG < GSC_ML, 0, 50))]

# Calculate Specific Spatial Confidence (SSC) - Confidence in area of sampled grid units as a percentage to the total unit area
# HERE WE NEED UNITS FILE
#units = readRDS(file = "my_units.rds")
wk3 <- merge(wk3, as.data.table(units)[, .(UnitArea = as.numeric(UnitArea)), keyby = .(UnitID)], by = c("UnitID"), all.x = TRUE)

print('wk3 3')

wk3[is.na(SSC), SSC := ifelse(GridArea / UnitArea * 100 > SSC_HM, 100, ifelse(GridArea / UnitArea * 100 < SSC_ML, 0, 50))]

print('wk3 4')

# Calculate Standard Error
wk3[, SE := SD / sqrt(N)]

# Calculate 95 % Confidence Interval
wk3[, CI := qnorm(0.975) * SE]

print('wk3 5')

# Calculate Eutrophication Ratio (ER)
wk3[, ER := ifelse(Response == 1, ES / ET, ET / ES)]

# Calculate (BEST)
wk3[, BEST := ifelse(Response == 1, ET / (1 + ACDEV / 100), ET / (1 - ACDEV / 100))]

print('wk3 6')

# Calculate Ecological Quality Ratio (EQR)
wk3[is.na(EQR), EQR := ifelse(Response == 1, ifelse(BEST > ES, 1, BEST / ES), ifelse(ES > BEST, 1, ES / BEST))]

print('wk3 7')

# Calculate Ecological Quality Ratio Boundaries (ERQ_HG/GM/MP/PB)
wk3[is.na(EQR_GM), EQR_GM := ifelse(Response == 1, 1 / (1 + ACDEV / 100), 1 - ACDEV / 100)]
wk3[is.na(EQR_HG), EQR_HG := 0.5 * 0.95 + 0.5 * EQR_GM]
wk3[is.na(EQR_PB), EQR_PB := 2 * EQR_GM - 0.95]
wk3[is.na(EQR_MP), EQR_MP := 0.5 * EQR_GM + 0.5 * EQR_PB]

print('wk3 8')

# Calculate Ecological Quality Ratio Scaled (EQRS)
wk3[is.na(EQRS), EQRS := ifelse(EQR <= EQR_PB, (EQR - 0) * (0.2 - 0) / (EQR_PB - 0) + 0,
                                ifelse(EQR <= EQR_MP, (EQR - EQR_PB) * (0.4 - 0.2) / (EQR_MP - EQR_PB) + 0.2,
                                       ifelse(EQR <= EQR_GM, (EQR - EQR_MP) * (0.6 - 0.4) / (EQR_GM - EQR_MP) + 0.4,
                                              ifelse(EQR <= EQR_HG, (EQR - EQR_GM) * (0.8 - 0.6) / (EQR_HG - EQR_GM) + 0.6,
                                                     (EQR - EQR_HG) * (1 - 0.8) / (1 - EQR_HG) + 0.8))))]

print(paste('Chlorophyll: in_combined_Chlorophylla_IsWeighted =', in_combined_Chlorophylla_IsWeighted))

# Calculate and add combined annual Chlorophyll a (In-Situ/EO/FB) indicator
if(in_combined_Chlorophylla_IsWeighted) {
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
print('Chlorophyll done')


# Calculate and add combined annual Cyanobacteria Bloom Index (BM/CSA) indicator
wk3_CBI <- wk3[IndicatorID %in% c(601, 602), .(IndicatorID = 6, ES = mean(ES, na.rm = TRUE), SD = NA, N = sum(N, na.rm = TRUE), NM = max(NM, na.rm = TRUE), ER = mean(ER, na.rm = TRUE), EQR = mean(EQR, na.rm = TRUE), EQRS = mean(EQRS, na.rm = TRUE), GTC = mean(GTC, na.rm = TRUE), NMP = max(NMP, na.rm = TRUE), STC = mean(STC, na.rm = TRUE), SSC = mean(SSC, na.rm = TRUE)), by = .(UnitID, Period)]
wk3 <- rbindlist(list(wk3, wk3_CBI), fill = TRUE)

setkey(wk3, IndicatorID, UnitID, Period)

# Classify Ecological Quality Ratio Scaled (EQRS_Class)
wk3[, EQRS_Class := ifelse(EQRS >= 0.8, "High",
                           ifelse(EQRS >= 0.6, "Good",
                                  ifelse(EQRS >= 0.4, "Moderate",
                                         ifelse(EQRS >= 0.2, "Poor","Bad"))))]


print('R script finished running.')

print(paste('Now writing outputs to', out_AnnualIndicatorPath))
data.table::fwrite(wk3, file = out_AnnualIndicatorPath)
print(paste('R script wrote outputs to', out_AnnualIndicatorPath))

