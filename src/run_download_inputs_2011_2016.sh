#!/usr/bin/env bash

# Define arguments:
assessmentPeriod="2011-2016" 
inputPath="../Input"

# Run R script:
Rscript --vanilla run_download_inputs.R $assessmentPeriod $inputPath
