
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
EQRS_Class_colors <- c(rgb(119,184,143,max=255), rgb(186,215,194,max=255), rgb(235,205,197,max=255), rgb(216,161,151,max=255), rgb(199,122,112,max=255))
EQRS_Class_limits <- c("High", "Good", "Moderate", "Poor", "Bad")
EQRS_Class_labels <- c(">= 0.8 - 1.0 (High)", ">= 0.6 - 0.8 (Good)", ">= 0.4 - 0.6 (Moderate)", ">= 0.2 - 0.4 (Poor)", ">= 0.0 - 0.2 (Bad)")

C_Class_colors <- c(rgb(252,231,218,max=255), rgb(245,183,142,max=255), rgb(204,100,23,max=255))
C_Class_limits <- c("High", "Moderate", "Low")
C_Class_labels <- c(">= 75 % (High)", "50 - 74 % (Moderate)", "< 50 % (Low)")

# Assessment map Status + Confidence
wk <- merge(units, wk9, all.x = TRUE, by = "UnitID")
if (verbose) message("Prepare plots... DONE.")

# Status maps
if (verbose) message("Create status maps...")
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
if (verbose) message("Create status maps... DONE.")

# Create Assessment Indicator maps
if (verbose) message("Create Assessment Indicator maps...")
## Re-reading indicators (also needed in heat3...)
indicators <- get_indicators_table(configurationFile)
n <- nrow(indicators[IndicatorID < 1000,])
for(i in 1:n) {
  indicatorID <- indicators[i, IndicatorID]
  indicatorCode <- indicators[i, Code]
  indicatorName <- indicators[i, Name]
  if (verbose) message(paste0("  Iteration ", i, "/", n, ", indicator name: ", indicatorName))
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
if (verbose) message("Create Assessment Indicator maps... DONE.")


# Create Annual Indicator bar charts
if (verbose) message("Create Annual Indicator bar charts...")
#for (i in 1:nrow(indicators[IndicatorID < 1000,])) {
n <- nrow(indicators[IndicatorID < 1000,])
for(i in 1:n) {
  indicatorID <- indicators[i, IndicatorID]
  indicatorCode <- indicators[i, Code]
  indicatorName <- indicators[i, Name]
  if (verbose) message(paste0("  Iteration ", i, "/", n, ", indicator name: ", indicatorName))
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
if (verbose) message("Create Annual Indicator bar charts... DONE.")
if (verbose) message(paste("Finished running for assessment period", assessmentPeriod, "..."))
message("Script finished.")
