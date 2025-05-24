#!/usr/bin/env bash

# Define arguments:
assessmentPeriod="2016-2021" 
inputPath="../Input"

# Run R script:
Rscript --vanilla run_download_inputs.R $assessmentPeriod $inputPath
