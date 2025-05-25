#!/usr/bin/env bash

# Define arguments:
#assessmentPeriod="1877-9999"
#assessmentPeriod="2011-2016"
#assessmentPeriod="2016-2021"
assessmentPeriod=$1
if [[ -z "$assessmentPeriod" ]]; then echo "Please provide an assessment period."; echo "Stopping."; exit 1; fi

#in_unitsFilePath="../Input/${assessmentPeriod}/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022_eutro.shp"
if [ $(assessmentPeriod) = '2011-2016' ]; then
    in_unitsFilePath="../Input/${assessmentPeriod}/AssessmentUnits.shp"
else
    in_unitsFilePath="../Input/${assessmentPeriod}/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022_eutro.shp"
fi
#in_unitGridSizePath="../Input/${assessmentPeriod}/Configuration${assessmentPeriod}.xlsx"
in_unitGridSizePath="../Input/${assessmentPeriod}/Configuration${assessmentPeriod}UnitGridSize.csv"
out_unitsCleanedFilePath="../testoutputs/units_cleaned${assessmentPeriod}.shp"
out_unitsGriddedFilePath="../testoutputs/units_gridded${assessmentPeriod}.shp"
out_plotsPath="../testoutputs"

# Run R script:
echo "Running run_heat1_csv.R for assessment period "${assessmentPeriod}

# without plotting:
#Rscript --vanilla run_heat1_csv.R $assessmentPeriod $in_unitsFilePath $in_unitGridSizePath $out_unitsCleanedFilePath $out_unitsGriddedFilePath

# with plotting:
Rscript --vanilla run_heat1_csv.R $assessmentPeriod $in_unitsFilePath $in_unitGridSizePath $out_unitsCleanedFilePath $out_unitsGriddedFilePath $out_plotsPath

