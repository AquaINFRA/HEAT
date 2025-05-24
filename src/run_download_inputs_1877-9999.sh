#!/usr/bin/env bash

# Define arguments:
assessmentPeriod="1877-9999" 
inputPath="../Input"

# Run R script:
Rscript --vanilla run_download_inputs.R $assessmentPeriod $inputPath
