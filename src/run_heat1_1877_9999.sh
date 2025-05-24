#!/usr/bin/env bash

# Define arguments:
assessmentPeriod="1877-9999" 
in_unitsFilePath="../Input/${assessmentPeriod}/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022_eutro.shp"
in_unitGridSizePath="../Input/${assessmentPeriod}/Configuration${assessmentPeriod}.xlsx"
out_unitsCleanedFilePath="../testoutputs/units_cleaned${assessmentPeriod}.shp"
out_unitsGriddedFilePath="../testoutputs/units_gridded${assessmentPeriod}.shp"
out_plotsPath="../testoutputs"

# Run R script:

# without plotting:
#Rscript --vanilla run_heat1.R $assessmentPeriod $in_unitsFilePath $in_unitGridSizePath $out_unitsCleanedFilePath $out_unitsGriddedFilePath

# with plotting:
Rscript --vanilla run_heat1.R $assessmentPeriod $in_unitsFilePath $in_unitGridSizePath $out_unitsCleanedFilePath $out_unitsGriddedFilePath $out_plotsPath

