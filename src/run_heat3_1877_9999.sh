#!/usr/bin/env bash

# Define arguments:
assessmentPeriod="1877-9999" 
in_relevantStationSamplesPath="../testoutputs/StationSamples${assessmentPeriod}.csv"
in_unitsCleanedFilePath="../testoutputs/units_cleaned${assessmentPeriod}.shp"
in_configurationFilePath="../Input/${assessmentPeriod}/Configuration${assessmentPeriod}.xlsx"
in_combined_Chlorophylla_IsWeighted="true"
out_AnnualIndicatorPath="../testoutputs/AnnualIndicators${assessmentPeriod}.csv"

# Run R script:
Rscript --vanilla run_heat3.R $in_relevantStationSamplesPath $in_unitsCleanedFilePath $in_configurationFilePath $in_combined_Chlorophylla_IsWeighted $out_AnnualIndicatorPath