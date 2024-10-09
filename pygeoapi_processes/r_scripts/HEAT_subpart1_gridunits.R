
# Import packages
library('readr') # to get "read_delim"
library('tidyverse')
library('sf') # to get "%>%"
library('data.table') # to get "setkey"

# User params
args <- commandArgs(trailingOnly = TRUE)
print(paste0('R Command line args: ', args))
assessmentPeriod = args[1]         # string
in_unitsFilePath = args[2]         # file, format: shp
in_unitGridSizePath = args[3]      # file, format: csv
out_unitsCleanedFilePath = args[4] # file, format: shp, written here
out_unitsGriddedFilePath = args[5] # file, format: shp, written here


# How to run this in bash:
#assessmentPeriod="2011-2016" 
#in_unitsFilePath="/home/work/inputs/2011-2016/AssessmentUnits.shp"
#in_unitGridSizePath="/home/work/inputs/2011-2016/Configuration2011-2016_UnitGridSize.csv"
#out_unitsCleanedFilePath="/home/work/testoutputs/units_cleaned.shp"
#out_unitsGriddedFilePath="/home/work/testoutputs/units_gridded.shp"
#Rscript --vanilla HEAT_subpart1_gridunits.R $assessmentPeriod $in_unitsFilePath $in_unitGridSizePath $out_unitsCleanedFilePath $out_unitsGriddedFilePath



# Create directory for outputs (in this case, PNG images!)
#dir.create(outputPath, showWarnings = FALSE, recursive = TRUE)


# Assessment Units + Grid Units-------------------------------------------------

if (assessmentPeriod == "2011-2016") {
  # Read assessment unit from shape file, requires sf
  units <- sf::st_read(in_unitsFilePath)
  
  # Filter for open sea assessment units, requires data.table
  units <- units[units$Code %like% 'SEA',]
  
  # Correct Description column name - temporary solution!
  colnames(units)[2] <- "Description"
  
  # Correct Åland Sea ascii character - temporary solution!
  units[14,2] <- 'Åland Sea'
  
  # Include stations from position 55.86667+-0.01667 12.75+-0.01667 which will include the Danish station KBH/DMU 431 and the Swedish station Wlandskrona into assessment unit 3/SEA-003
  units[3,] <- sf::st_union(units[3,],sf::st_as_sfc("POLYGON((12.73333 55.85,12.73333 55.88334,12.76667 55.88334,12.76667 55.85,12.73333 55.85))", crs = 4326))
  
  # Assign IDs
  units$UnitID = 1:nrow(units)
  
  # Transform projection into ETRS_1989_LAEA
  units <- sf::st_transform(units, crs = 3035)
  
  # Calculate area
  units$UnitArea <- sf::st_area(units)
} else {
  # Read assessment unit from shape file
  units <- sf::st_read(in_unitsFilePath) %>% st_zm()
  
  # Filter for open sea assessment units
  units <- units[units$HELCOM_ID %like% 'SEA',]
  
  # Include stations from position 55.86667+-0.01667 12.75+-0.01667 which will include the Danish station KBH/DMU 431 and the Swedish station Wlandskrona into assessment unit 3/SEA-003
  units[3,] <- sf::st_union(units[3,],sf::st_transform(sf::st_as_sfc("POLYGON((12.73333 55.85,12.73333 55.88334,12.76667 55.88334,12.76667 55.85,12.73333 55.85))", crs = 4326), crs = 3035))
  
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
sf::st_is_valid(units) # doppelt?

# Make geometries valid by doing the buffer of nothing trick
#units <- sf::st_buffer(units, 0.0)

# Identify overlapping assessment units
#sf::st_overlaps(units)

# Make grid units
make.gridunits <- function(units, gridSize) {
  units <- sf::st_transform(units, crs = 3035)
  
  bbox <- sf::st_bbox(units)
  
  xmin <- floor(bbox$xmin / gridSize) * gridSize
  ymin <- floor(bbox$ymin / gridSize) * gridSize
  xmax <- ceiling(bbox$xmax / gridSize) * gridSize
  ymax <- ceiling(bbox$ymax / gridSize) * gridSize
  
  xn <- (xmax - xmin) / gridSize
  yn <- (ymax - ymin) / gridSize
  
  grid <- sf::st_make_grid(units, cellsize = gridSize, c(xmin, ymin), n = c(xn, yn), crs = 3035) %>%
    sf::st_sf()
  
  grid$GridID = 1:nrow(grid)
  
  gridunits <- sf::st_intersection(grid, units)
  
  gridunits$Area <- sf::st_area(gridunits)
  
  return(gridunits)
}

gridunits10 <- make.gridunits(units, 10000)
gridunits30 <- make.gridunits(units, 30000)
gridunits60 <- make.gridunits(units, 60000)

# This needs "readxl"/"readr"
#unitGridSize <- as.data.table(read_excel(in_configurationFilePath, sheet = "UnitGridSize")) %>% setkey(UnitID)
print(paste('Reading indicators from', in_unitGridSizePath))
unitGridSize = as.data.table(readr::read_delim(in_unitGridSizePath, delim=";", col_types = "ii")) %>% setkey(UnitID)


a <- merge(unitGridSize[GridSize == 10000], gridunits10 %>% select(UnitID, GridID, GridArea = Area))
b <- merge(unitGridSize[GridSize == 30000], gridunits30 %>% select(UnitID, GridID, GridArea = Area))
c <- merge(unitGridSize[GridSize == 60000], gridunits60 %>% select(UnitID, GridID, GridArea = Area))
gridunits <- sf::st_as_sf(rbindlist(list(a,b,c)))
rm(a,b,c)

gridunits <- sf::st_cast(gridunits)

#sf::st_write(gridunits, file.path(outputPath, "gridunits.shp"), delete_layer = TRUE)

# Plot the assessment units
#print(paste('Storing PNG graphics to', outputPath))
#pdf(file = NULL)
#ggplot() + geom_sf(data = units) + coord_sf()
#ggsave(file.path(outputPath, "Assessment_Units.png"), width = 12, height = 9, dpi = 300)
#ggplot() + geom_sf(data = gridunits10) + coord_sf()
#ggsave(file.path(outputPath, "Assessment_GridUnits10.png"), width = 12, height = 9, dpi = 300)
#ggplot() + geom_sf(data = gridunits30) + coord_sf()
#ggsave(file.path(outputPath, "Assessment_GridUnits30.png"), width = 12, height = 9, dpi = 300)
#ggplot() + geom_sf(data = gridunits60) + coord_sf()
#ggsave(file.path(outputPath, "Assessment_GridUnits60.png"), width = 12, height = 9, dpi = 300)
#ggplot() + geom_sf(data = sf::st_cast(gridunits)) + coord_sf()
#ggsave(file.path(outputPath, "Assessment_GridUnits.png"), width = 12, height = 9, dpi = 300)
#print(paste('Stored into', outputPath, ': Assessment_Units.png, Assessment_GridUnits10.png, Assessment_GridUnits20.png, Assessment_GridUnits60.png, Assessment_GridUnits.png'))
# Done!

print('R script finished running.')

# TODO: These fail if the files already exist:
sf::st_write(gridunits, out_unitsGriddedFilePath, delete_layer = TRUE)
print(paste('Stored intermediate result:', out_unitsGriddedFilePath))
sf::st_write(units, out_unitsCleanedFilePath)
print(paste('Stored intermediate result:', out_unitsCleanedFilePath))

