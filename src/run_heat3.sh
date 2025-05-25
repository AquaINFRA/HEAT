#!/usr/bin/env bash

# Define arguments:
#assessmentPeriod="1877-9999"
#assessmentPeriod="2011-2016"
#assessmentPeriod="2016-2021"
assessmentPeriod=$1
if [[ -z "$assessmentPeriod" ]]; then echo "Please provide an assessment period."; echo "Stopping."; exit 1; fi

in_relevantStationSamplesPath="../testoutputs/StationSamples${assessmentPeriod}.csv"
in_unitsCleanedFilePath="../testoutputs/units_cleaned${assessmentPeriod}.shp"
in_configurationFilePath="../Input/${assessmentPeriod}/Configuration${assessmentPeriod}.xlsx"
in_combined_Chlorophylla_IsWeighted="true"
out_AnnualIndicatorPath="../testoutputs/AnnualIndicators${assessmentPeriod}.csv"

# Run R script:
echo "Running run_heat3.R for assessment period "${assessmentPeriod}
Rscript --vanilla run_heat3.R $in_relevantStationSamplesPath $in_unitsCleanedFilePath $in_configurationFilePath $in_combined_Chlorophylla_IsWeighted $out_AnnualIndicatorPath