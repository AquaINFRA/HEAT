#!/usr/bin/env bash

# Define arguments:
#in_unitsFilePath="../adapted_inputs/dummy/dummytest_epsg3035_unitid.shp"
in_unitsFilePath="../adapted_inputs/dummy/dummytest_epsg4326_unitid.shp"
in_unitGridSizePath="../adapted_inputs/dummy/dummy_UnitGridSize_generic.csv"
out_unitsCleanedFilePath="../testoutputs/units_cleaned_dummy.shp"
out_unitsGriddedFilePath="../testoutputs/units_gridded_dummy.shp"
out_plotsPath="../testoutputs"

# Run R script:
echo "Running run_heat1_csv_generic.R"

# without plotting:
Rscript --vanilla run_heat1_csv_generic.R $in_unitsFilePath $in_unitGridSizePath $out_unitsCleanedFilePath $out_unitsGriddedFilePath

# with plotting:
#Rscript --vanilla run_heat1_csv_generic.R $in_unitsFilePath $in_unitGridSizePath $out_unitsCleanedFilePath $out_unitsGriddedFilePath $out_plotsPath

