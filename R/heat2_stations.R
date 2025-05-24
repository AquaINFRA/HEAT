library(data.table) # fread, uniqueN

prepare_station_samples <- function(stationSamplesBOTFile, stationSamplesCTDFile, stationSamplesPMPFile, gridunits, verbose=TRUE, veryverbose=FALSE) {

    if (verbose) message("Reading station sample data...")

    # Ocean hydro chemistry - Bottle and low resolution CTD data
    stationSamplesBOT <- data.table::fread(input = stationSamplesBOTFile, sep = "\t", na.strings = "NULL", stringsAsFactors = FALSE, header = TRUE, check.names = TRUE)
    stationSamplesBOT[, Type := "B"]

    # Ocean hydro chemistry - High resolution CTD data
    stationSamplesCTD <- data.table::fread(input = stationSamplesCTDFile, sep = "\t", na.strings = "NULL", stringsAsFactors = FALSE, header = TRUE, check.names = TRUE)
    stationSamplesCTD[, Type := "C"]

    # Ocean hydro chemistry - Pump data
    stationSamplesPMP <- data.table::fread(input = stationSamplesPMPFile, sep = "\t", na.strings = "NULL", stringsAsFactors = FALSE, header = TRUE, check.names = TRUE)
    stationSamplesPMP[, Type := "P"]

    # Combine station samples
    stationSamples <- rbindlist(list(stationSamplesBOT, stationSamplesCTD, stationSamplesPMP), use.names = TRUE, fill = TRUE)

    # Remove original data tables
    rm(stationSamplesBOT, stationSamplesCTD, stationSamplesPMP)

    # Unique stations by natural key
    if (verbose) message('unique:')
    data.table::uniqueN(stationSamples, by = c("Cruise", "Station", "Type", "Year", "Month", "Day", "Hour", "Minute", "Longitude..degrees_east.", "Latitude..degrees_north."))

    # Assign station ID by natural key
    stationSamples[, StationID := .GRP, by = .(Cruise, Station, Type, Year, Month, Day, Hour, Minute, Longitude..degrees_east., Latitude..degrees_north.)]
    if (verbose) message("Reading station sample data... DONE.")

    # Classify station samples into grid units -------------------------------------
    if (verbose) message("Classifying station samples into grid units...")

    # Extract unique stations i.e. longitude/latitude pairs
    stations <- unique(stationSamples[, .(Longitude..degrees_east., Latitude..degrees_north.)])
    if (verbose) message(paste('Stations colnames:', paste(colnames(stations), collapse=",")))

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
    if (verbose) message("Classifying station samples into grid units... DONE.")

    return (stationSamples)
}