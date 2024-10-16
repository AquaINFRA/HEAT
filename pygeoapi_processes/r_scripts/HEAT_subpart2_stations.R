
# Import packages
library(sf)         # to get "%>%", st_read, ...
library(data.table) # to get fread
library(R.utils)    # also for fread...
library(lubridate)  # for parsing the date from ICES-provided data

# User params
args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
in_stationSamplesBOTFilePath = args[1]  # file, format: txt.gz OR csv
in_stationSamplesCTDFilePath = args[2]  # file, format: txt.gz
in_stationSamplesPMPFilePath = args[3]  # file, format: txt.gz
in_unitsGriddedFilePath = args[4]       # file, format: shp
out_stationSamplesBOTFilePath = args[5] # file, format: csv, written here
out_stationSamplesCTDFilePath = args[6] # file, format: csv, written here
out_stationSamplesPMPFilePath = args[7] # file, format: csv, written here
out_stationSamplesTableCSVFilePath = args[8] # file, format: csv, written here

# How to run this in bash:
#in_stationSamplesBOTFilePath="/home/work/inputs/2016-2021/StationSamples2016-2021BOT_2022-12-09.txt.gz"
#in_stationSamplesCTDFilePath="/home/work/inputs/2016-2021/StationSamples2016-2021CTD_2022-12-09.txt.gz"
#in_stationSamplesPMPFilePath="/home/work/inputs/2016-2021/StationSamples2016-2021PMP_2022-12-09.txt.gz"
#in_unitsGriddedFilePath="/home/work/testoutputs/units_gridded.shp"
#out_stationSamplesBOTFilePath="/home/work/testoutputs/StationSamplesBOT.csv"
#out_stationSamplesCTDFilePath="/home/work/testoutputs/StationSamplesCTD.csv"
#out_stationSamplesPMPFilePath="/home/work/testoutputs/StationSamplesPMP.csv"
#out_stationSamplesTableCSVFilePath="/home/work/testoutputs/StationSamples.csv"
#Rscript --vanilla HEAT_subpart2_stations.R $in_stationSamplesBOTFilePath $in_stationSamplesCTDFilePath $in_stationSamplesPMPFilePath $in_unitsGriddedFilePath $out_stationSamplesBOTFilePath $out_stationSamplesCTDFilePath $out_stationSamplesPMPFilePath $out_stationSamplesTableCSVFilePath


# Load required intermediate file:
print(paste('Now reading spatial units from:', in_unitsGriddedFilePath))
gridunits <- sf::st_read(in_unitsGriddedFilePath)


# In this script, all files are treated equally, so we just let the client pass the file name.
print(paste('stationSamplesBOTFile:', in_stationSamplesBOTFilePath))
print(paste('stationSamplesCTDFile:', in_stationSamplesCTDFilePath))
print(paste('stationSamplesPMPFile:', in_stationSamplesPMPFilePath))


# Ocean hydro chemistry - Bottle and low resolution CTD data, needs "data.table"
# Trying to read with separator "tab":
# TODO: how to know whether we failed?
stationSamplesBOT <- data.table::fread(input = in_stationSamplesBOTFilePath, sep = "\t", na.strings = "NULL", stringsAsFactors = FALSE, header = TRUE, check.names = TRUE)
if (ncol(stationSamplesBOT) == 1) {
	message(paste0('Only one column found in: ', in_stationSamplesBOTFilePath))
	message('Probably used the wrong separator (tab). Trying with comma...')
    stationSamplesBOT <- data.table::fread(input = in_stationSamplesBOTFilePath, sep = ",", na.strings = "NULL", stringsAsFactors = FALSE, header = TRUE, check.names = TRUE)
}
stationSamplesBOT[, Type := "B"]

# If there is no column "Year", we likely have data dowloaded from ICES, which has the date in one column.
# In this case, separate it into various columns:
if (!('Year' %in% colnames(stationSamplesBOT))){
	message('Column "Year" not found. Looking for other date column.') # TODO Use "missing()" here? For all required columns?
	if ('yyyy.mm.ddThh.mm.ss.sss' %in% colnames(stationSamplesBOT)) {
		message('We found column "yyyy.mm.ddThh.mm.ss.sss"... Will try to parse it.')
		stationSamplesBOT$tempdate <- as.POSIXct(stationSamplesBOT$yyyy.mm.ddThh.mm.ss.sss, format="%Y-%m-%dT%H:%M")
		stationSamplesBOT$Year <- lubridate::year(stationSamplesBOT$tempdate)
		stationSamplesBOT$Month <- lubridate::month(stationSamplesBOT$tempdate) 
		stationSamplesBOT$Day <- lubridate::day(stationSamplesBOT$tempdate)
		stationSamplesBOT$Hour <- lubridate::hour(stationSamplesBOT$tempdate)
		stationSamplesBOT$Minute <- lubridate::minute(stationSamplesBOT$tempdate)
    #message(paste0('All col names: ', paste(colnames(stationSamplesBOT), collapse=',')))
	}
}


### Replace column names in the ICES format by column names the HELCOM format!

colname_pairs = list(
  c('Secchi.Depth..m..METAVAR.FLOAT', 'Secchi.Depth..m.'),
  c('Depth..m.', 'Depth..ADEPZZ01_ULAA...m.'),
  c('QV.ODV.Depth..m.', 'QV.ODV.Depth..ADEPZZ01_ULAA.'),
  c('Temperature..degC.', 'Temperature..TEMPPR01_UPAA...degC.'),
  c('QV.ODV.Temperature..degC.', 'QV.ODV.Temperature..TEMPPR01_UPAA.'),
  c('Secchi.Depth..m..METAVAR.FLOAT', 'Secchi.Depth..m.'),
  c('QV.ODV.Secchi.Depth..m.', 'QV.ODV.Secchi.Depth..m.'),
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

message(paste0('Now checking the col names...'))
for (colname_pair in colname_pairs) {
  message(paste('* colname_pair: ', colname_pair))
  colname_helcom = colname_pair[1]
  message(paste('* colname_helcom: ', colname_helcom))
  colname_ices = colname_pair[2]
  message(paste('* colname_ices: ', colname_ices))

  if (colname_helcom %in% colnames(stationSamplesBOT)) {
      message(paste0('Colname exists: "', colname_helcom, '".'))
  } else {
    if (colname_ices %in% colnames(stationSamplesBOT)) {
      message(paste0('Replacing column "', colname_ices, '" by "', colname_helcom, '"...'))
    } else {
      message(paste0('Column missing "', colname_helcom, '" (or its ICES alternative "', colname_ices, '")...'))
    }
  }
}
message(paste0('Done checking the col names...'))


# Ocean hydro chemistry - High resolution CTD data
# TODO also check whether this might be ICES-format data?
stationSamplesCTD <- data.table::fread(input = in_stationSamplesCTDFilePath, sep = "\t", na.strings = "NULL", stringsAsFactors = FALSE, header = TRUE, check.names = TRUE)
if (ncol(stationSamplesCTD) == 1) {
	message(paste0('Only one column found in: ', in_stationSamplesCTDFilePath))
	message('Probably used the wrong separator (tab). Should try with comma...')
	stop('Not implemented yet: Parsing CTD data with comma.')
}
stationSamplesCTD[, Type := "C"]

# Ocean hydro chemistry - Pump data
# TODO also check whether this might be ICES-format data?
stationSamplesPMP <- data.table::fread(input = in_stationSamplesPMPFilePath, sep = "\t", na.strings = "NULL", stringsAsFactors = FALSE, header = TRUE, check.names = TRUE)
if (ncol(stationSamplesPMP) == 1) {
	message(paste0('Only one column found in: ', in_stationSamplesPMPFilePath))
	message('Probably used the wrong separator (tab). Should try with comma...')
	stop('Not implemented yet: Parsing PMP data with comma.')
}
stationSamplesPMP[, Type := "P"]

#> length(names(stationSamplesBOT)) #[1] 46
#> length(names(stationSamplesCTD)) #[1] 28
#> length(names(stationSamplesPMP)) #[1] 32

#> length(intersect(names(stationSamplesPMP), names(stationSamplesCTD))) #[1] 20
#> length(intersect(names(stationSamplesPMP), names(stationSamplesBOT))) #[1] 32
#> length(intersect(names(stationSamplesCTD), names(stationSamplesBOT))) #[1] 28

#length(intersect(names(stationSamplesBOT),intersect(names(stationSamplesPMP), names(stationSamplesCTD)))) #[1] 20
#intersect(names(stationSamplesBOT),intersect(names(stationSamplesPMP), names(stationSamplesCTD)))
# "Cruise", "Station", "Type", "Year", "Month", "Day", "Hour", "Minute"                             
# "Longitude..degrees_east.", "Latitude..degrees_north."           
# "Bot..Depth..m."                "QV.ODV.Bot.Depth..m."               
# "Depth..m."                     "QV.ODV.Depth..m."                   
# "Temperature..degC."            "QV.ODV.Temperature..degC."          
# "Practical.Salinity..dmnless."  "QV.ODV.Practical.Salinity..dmnless."
# "Chlorophyll.a..ug.l."          "QV.ODV.Chlorophyll.a..ug.l."  

# Combine station samples
print('bind lists...')
stationSamples <- rbindlist(list(stationSamplesBOT, stationSamplesCTD, stationSamplesPMP), use.names = TRUE, fill = TRUE)

# Remove original data tables
rm(stationSamplesBOT, stationSamplesCTD, stationSamplesPMP)

# Unique stations by natural key
print('unique:')
#uniqueN(stationSamples, by = c("Cruise", "Station", "Type", "Year", "Month", "Day", "Hour", "Minute", "Longitude..degrees_east.", "Latitude..degrees_north."))
data.table::uniqueN(stationSamples, by = c("Cruise", "Station", "Type", "Year", "Month", "Day", "Hour", "Minute", "Longitude..degrees_east.", "Latitude..degrees_north."))

# Assign station ID by natural key
stationSamples[, StationID := .GRP, by = .(Cruise, Station, Type, Year, Month, Day, Hour, Minute, Longitude..degrees_east., Latitude..degrees_north.)]





# Classify station samples into grid units -------------------------------------

# Extract unique stations i.e. longitude/latitude pairs
stations <- unique(stationSamples[, .(Longitude..degrees_east., Latitude..degrees_north.)])

# Make stations spatial keeping original latitude/longitude. This needs "sf"
print('Start st_as_sf...')
print(paste0('COLL:', colnames(stations)))
stations <- sf::st_as_sf(stations, coords = c("Longitude..degrees_east.", "Latitude..degrees_north."), remove = FALSE, crs = 4326)

# Transform projection into ETRS_1989_LAEA
print('Start st_transform')
stations <- sf::st_transform(stations, crs = 3035)

# Classify stations into grid units
# GRIDUNITS!!
#gridunits = readRDS(file = "my_gridunits.rds")
stations <- sf::st_join(stations, gridunits, join = st_intersects)

# Delete stations not classified
stations <- na.omit(stations)

# Remove spatial column and nake into data table
stations <- sf::st_set_geometry(stations, NULL) %>% as.data.table()

# Merge stations back into station samples - getting rid of station samples not classified into assessment units
stationSamples <- stations[stationSamples, on = .(Longitude..degrees_east., Latitude..degrees_north.), nomatch = 0]



print('R script finished running.')



print('Now writing outputs...')
data.table::fwrite(stationSamples, out_stationSamplesTableCSVFilePath, row.names = TRUE)

# Output station samples mapped to assessment units for contracting parties to check i.e. acceptance level 1
data.table::fwrite(stationSamples[Type == 'B'], out_stationSamplesBOTFilePath)
data.table::fwrite(stationSamples[Type == 'C'], out_stationSamplesCTDFilePath)
data.table::fwrite(stationSamples[Type == 'P'], out_stationSamplesPMPFilePath)
print('Output written...')
