#!/usr/bin/env bash

# Define arguments:
assessmentPeriod="1877-9999"
in_AssessmentIndicatorPath="../testoutputs/AssessmentIndicators${assessmentPeriod}.csv"
in_configurationFilePath="../Input/${assessmentPeriod}/Configuration${assessmentPeriod}.xlsx"
out_AssessmentPath="../testoutputs/Assessment${assessmentPeriod}.csv"

# Run R script:
Rscript --vanilla run_heat5.R $in_AssessmentIndicatorPath $in_configurationFilePath $out_AssessmentPath
