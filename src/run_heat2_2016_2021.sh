#!/usr/bin/env bash

# Define arguments:
assessmentPeriod="2016-2021" 
in_stationSamplesBOTFilePath="../Input/${assessmentPeriod}/StationSamples${assessmentPeriod}BOT_2022-12-09.txt.gz"
in_stationSamplesCTDFilePath="../Input/${assessmentPeriod}/StationSamples${assessmentPeriod}CTD_2022-12-09.txt.gz"
in_stationSamplesPMPFilePath="../Input/${assessmentPeriod}/StationSamples${assessmentPeriod}PMP_2022-12-09.txt.gz"
in_unitsGriddedFilePath="../testoutputs/units_gridded${assessmentPeriod}.shp"
out_stationSamplesBOTFilePath="../testoutputs/StationSamples${assessmentPeriod}BOT.csv"
out_stationSamplesCTDFilePath="../testoutputs/StationSamples${assessmentPeriod}CTD.csv"
out_stationSamplesPMPFilePath="../testoutputs/StationSamples${assessmentPeriod}PMP.csv"
out_stationSamplesTableCSVFilePath="../testoutputs/StationSamples${assessmentPeriod}.csv"

# Run R script:
Rscript --vanilla run_heat2.R $in_stationSamplesBOTFilePath $in_stationSamplesCTDFilePath $in_stationSamplesPMPFilePath $in_unitsGriddedFilePath $out_stationSamplesBOTFilePath $out_stationSamplesCTDFilePath $out_stationSamplesPMPFilePath $out_stationSamplesTableCSVFilePath
