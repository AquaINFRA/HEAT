
verbose <- TRUE

# Install and load R packages ---------------------------------------------
if (verbose) message("Install and load R packages...")
ipak <- function(pkg){
  new.pkg <- pkg[!(pkg %in% installed.packages()[, "Package"])]
  if (length(new.pkg)) 
    install.packages(new.pkg, dependencies = TRUE)
  sapply(pkg, require, character.only = TRUE)
}
packages <- c("sf", "data.table", "tidyverse", "readxl", "ggplot2", "ggmap", "mapview", "httr", "R.utils")
ipak(packages)
if (verbose) message("Install and load R packages... DONE.")
source("./R/all_heat_functions.R")
source("./R/heat_plot_functions.R")

# Define assessment period i.e. uncomment the period you want to run the assessment for!
#assessmentPeriod <- "1877-9999"
#assessmentPeriod <- "2011-2016" # HOLAS II
assessmentPeriod <- "2016-2021" # HOLAS III
message(paste("Running for assessment period", assessmentPeriod, "..."))

# Set flag to determined if the combined chlorophyll a in-situ/satellite indicator is a simple mean or a weighted mean based on confidence measures
combined_Chlorophylla_IsWeighted <- TRUE

# Define paths
inputPath <- file.path("Input", assessmentPeriod)
outputPath <- file.path("Output", assessmentPeriod)

# Create paths
dir.create(inputPath, showWarnings = FALSE, recursive = TRUE)
dir.create(outputPath, showWarnings = FALSE, recursive = TRUE)

# Download all inputs
paths <- download_inputs(assessmentPeriod, inputPath, verbose)
unitsFile <- paths$unitsFile
configurationFile <- paths$configurationFile
stationSamplesBOTFile <- paths$stationSamplesBOTFile
stationSamplesCTDFile <- paths$stationSamplesCTDFile
stationSamplesPMPFile <- paths$stationSamplesPMPFile

# Assessment Units + Grid Units-------------------------------------------------
if (verbose) message("Generating assessment Units and Grid Units...")
units <- get_units(assessmentPeriod, unitsFile, verbose)
unitGridSizeTable <- get_unit_grid_size_table(configurationFile, format='xlsx')
gridunits <- get_gridunits(units, unitGridSizeTable, verbose)
if (verbose) message("Generating assessment Units and Grid Units... DONE.")

#st_write(gridunits, file.path(outputPath, "gridunits.shp"), delete_layer = TRUE)

# Plot
if (verbose) message("Plotting...")
# For plotting, we recreate the non-combined gridunits files. They are not
# required for the rest of the computation script.
gridunits10 <- make.gridunits(units, 10000, verbose)
gridunits30 <- make.gridunits(units, 30000, verbose)
gridunits60 <- make.gridunits(units, 60000, verbose)
plot_spatial_units(units, outputPath, "Assessment_Units.png")
plot_spatial_units(gridunits10, outputPath, "Assessment_GridUnits10.png")
plot_spatial_units(gridunits30, outputPath, "Assessment_GridUnits30.png")
plot_spatial_units(gridunits60, outputPath, "Assessment_GridUnits60.png")
plot_spatial_units(st_cast(gridunits), outputPath, "Assessment_GridUnits.png")
if (verbose) message("Plotting... DONE")


# Read station sample data -----------------------------------------------------
if (verbose) message("Generating station sample data...")
stationSamples <- prepare_station_samples(stationSamplesBOTFile, stationSamplesCTDFile, stationSamplesPMPFile, gridunits, verbose)
if (verbose) message("Generating station sample data... DONE.")

# Output station samples mapped to assessment units for contracting parties to check i.e. acceptance level 1
fwrite(stationSamples[Type == 'B'], file.path(outputPath, "StationSamplesBOT.csv"))
fwrite(stationSamples[Type == 'C'], file.path(outputPath, "StationSamplesCTD.csv"))
fwrite(stationSamples[Type == 'P'], file.path(outputPath, "StationSamplesPMP.csv"))

# Also write combined station samples:
fwrite(stationSamples, file.path(outputPath, "StationSamples_combined.csv"), row.names = TRUE)


# Read indicator configs -------------------------------------------------------
indicators <- get_indicators_table(configurationFile, format="xlsx")
indicatorUnits <- get_indicator_units_table(configurationFile, format="xlsx")
indicatorUnitResults <- get_indicator_unit_results_table(configurationFile, format="xlsx")

# Loop indicators --------------------------------------------------------------
if (verbose) message("Looping over the indicators  (and some more)...")
wk3 <- compute_annual_indicators(stationSamples, units, indicators, indicatorUnits, indicatorUnitResults, combined_Chlorophylla_IsWeighted, verbose)
if (verbose) message("Looping over the indicators (and some more)... DONE")

# ------------------------------------------------------------------------------
# Calculate assessment means --> UnitID, Period, ES, SD, N, N_OBS, EQR, EQRS GTC, STC, SSC
# Confidence Assessment---------------------------------------------------------
if (verbose) message("Calculating assessment means and confidence assessment...")
wk5 <- compute_assessment_indicators(wk3, indicators, indicatorUnits, verbose)
if (verbose) message("Calculating assessment means and confidence assessment... DONE.")


# Criteria ---------------------------------------------------------------------
# Assessment -------------------------------------------------------------------
if (verbose) message("Criteria, Assessment...")
wk9 <- compute_assessment(wk5, indicators, indicatorUnits, verbose)
if (verbose) message("Criteria, Assessment... DONE.")


# Write results
if (verbose) message("Write results...")
fwrite(wk3, file = file.path(outputPath, "Annual_Indicator.csv"))
fwrite(wk5, file = file.path(outputPath, "Assessment_Indicator.csv"))
fwrite(wk9, file = file.path(outputPath, "Assessment.csv"))
if (verbose) message("Write results... DONE.")

# Create plots
if (verbose) message("Prepare plots...")
EQRS_Classes <- get_EQRS_colors()
C_Classes <- get_C_colors()
if (verbose) message("Prepare plots... DONE.")

# Assessment map Status + Confidence

# Status maps
if (verbose) message("Create status maps...")
plot_status_maps(wk9, units, assessmentPeriod, EQRS_Classes, C_Classes, outputPath, verbose)
if (verbose) message("Create status maps... DONE.")

# Create Assessment Indicator maps
if (verbose) message("Create Assessment Indicator maps...")
plot_assessment_indicator_maps(wk5, units, indicators, EQRS_Classes, C_Classes, outputPath, verbose)
if (verbose) message("Create Assessment Indicator maps... DONE.")


# Create Annual Indicator bar charts
if (verbose) message("Create Annual Indicator bar charts...")
plot_annual_indicator_barcharts(wk3, units, indicators, outputPath, verbose)
if (verbose) message("Create Annual Indicator bar charts... DONE.")
if (verbose) message(paste("Finished running for assessment period", assessmentPeriod, "..."))
message("Script finished.")
