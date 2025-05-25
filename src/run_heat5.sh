#!/usr/bin/env bash

# Define arguments:
#assessmentPeriod="1877-9999"
#assessmentPeriod="2011-2016"
#assessmentPeriod="2016-2021"
assessmentPeriod=$1
if [[ -z "$assessmentPeriod" ]]; then echo "Please provide an assessment period."; echo "Stopping."; exit 1; fi

in_AssessmentIndicatorPath="../testoutputs/AssessmentIndicators${assessmentPeriod}.csv"
in_configurationFilePath="../Input/${assessmentPeriod}/Configuration${assessmentPeriod}.xlsx"
out_AssessmentPath="../testoutputs/Assessment${assessmentPeriod}.csv"

# Run R script:
echo "Running run_heat5.R for assessment period "${assessmentPeriod}
Rscript --vanilla run_heat5.R $in_AssessmentIndicatorPath $in_configurationFilePath $out_AssessmentPath
