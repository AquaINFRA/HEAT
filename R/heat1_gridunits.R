library(sf)         # %>%, st_...
library(data.table) # setkey
library(readxl)     # read_excel
library(tidyverse)  # select


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

get_gridunits <- function(units, configurationFile, verbose=TRUE) {
  if (verbose) message(paste("START: get_gridunits"))

  gridunits10 <- make.gridunits(units, 10000, verbose)
  gridunits30 <- make.gridunits(units, 30000, verbose)
  gridunits60 <- make.gridunits(units, 60000, verbose)

  unitGridSize <- as.data.table(readxl::read_excel(configurationFile, sheet = "UnitGridSize")) %>% data.table::setkey(UnitID)

  a <- merge(unitGridSize[GridSize == 10000], gridunits10 %>% select(UnitID, GridID, GridArea = Area))
  b <- merge(unitGridSize[GridSize == 30000], gridunits30 %>% select(UnitID, GridID, GridArea = Area))
  c <- merge(unitGridSize[GridSize == 60000], gridunits60 %>% select(UnitID, GridID, GridArea = Area))

  gridunits <- sf::st_as_sf(rbindlist(list(a,b,c)))
  gridunits <- sf::st_cast(gridunits)

  rm(a,b,c)

  if (verbose) message(paste("END:   get_gridunits"))
  return(gridunits)
}


# Make grid units
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

