#!/usr/bin/env bash

# Define arguments:
# Define arguments:
#assessmentPeriod="1877-9999"
#assessmentPeriod="2011-2016"
#assessmentPeriod="2016-2021"
assessmentPeriod=$1
if [[ -z "$assessmentPeriod" ]]; then echo "Please provide an assessment period."; echo "Stopping."; exit 1; fi

inputPath="../Input"

# Run R script:
echo "Running run_download_inputs.R for assessment period "${assessmentPeriod}
Rscript --vanilla run_download_inputs.R $assessmentPeriod $inputPath
