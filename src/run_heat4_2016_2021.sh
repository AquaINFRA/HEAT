#!/usr/bin/env bash

# Define arguments:
assessmentPeriod="2016-2021" 
in_AnnualIndicatorPath="../testoutputs/AnnualIndicators${assessmentPeriod}.csv"
in_configurationFilePath="../Input/${assessmentPeriod}/Configuration${assessmentPeriod}.xlsx"
out_AssessmentIndicatorPath="../testoutputs/AssessmentIndicators${assessmentPeriod}.csv"

# Run R script:
Rscript --vanilla run_heat4.R $in_AnnualIndicatorPath $in_configurationFilePath $out_AssessmentIndicatorPath
