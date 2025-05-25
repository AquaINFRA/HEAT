# HELCOM Eutrophication Assessment Tool (HEAT)

Assessment units are defined by HELCOM comtracting parties. An assessment units can have multiple indicators. Each indicator can have different temporal (months) and spatial (depths) coverage and reference values within the different assessment units. 

### Assessment Units

### Station Samples

### Indicator Definitions

### Common Indicators

- Dissolved Inorganic Nitrogen (DIN)
- Dissolved Inorganic Phosphorus (DIP)
- Chlorophyll a
- Secchi Depth
- Oxygen Debt
- Total Nitrogen (TN)
- Total Phosphorus (TP)
- Cyanobacteria Bloom Index (CyaBI)

### Abbreviations

- ES = Eutrophication Status
- ES_SD = Standard Deviation
- ES_N = Number of Observations
- ES_N_Min = Minimum Number of Observations any given year 
- ES_SE = Standards Error
- ES_CI = Confidense Interval
- ET = Eutrophication Target / Threshold
- ER = Eutrophication Ratio
- ACDEV = Acceptable Deviation
- BEST = ET / (1 + ACDEV / 100)
- EQR = Ecological Quality Ratio
- EQR_HG = Ecological Quality Ratio High/Good Boundary
- EQR_GM = Ecological Quality Ratio Good/Moderate Boundary
- EQR_MP = Ecological Quality Ratio Moderate/Poor Boundary
- EQR_PB = Ecological Quality Ratio Poor/Bad Boundary
- EQRS = Ecological Quality Ratio Scaled
- GTC = General Temporal Confidence
- STC = Specific Temporal Confindence
- TTC = Total Temporal Confidence
- GSC = General Spatial Confidence 
- SSC = Specific Spatial Confidence
- TSC = Total Spatial Confidence
- TC = Total Confidence

### Modularized

The original script `HEAT.R` was one long R script that did a lot of things.

In the scope of the project AquaINFRA, it was modularized: Pieces of code
were taken out of `HEAT.R` and written as functions, which are stored in
`R/all_heat_functions.R`, while the pieces of code that generate plots are
stored as functions in `R/heat_plot_functions.R`.

Now the `HEAT.R` sources those two files and calls the functions. The result
should be the same, but there is no guarantee we did not mess up anything.
Ideally, this should be thoroughly tested before used in real life.

Also, the various functions can now be used separately. As examples, various
R scripts (and also bash scripts calling those R scripts) can be found in the
directory `/src`. The purpose of this exercise was that we wanted to provide
various parts of HEAT separately on a server (using the OGC API).

So you can eigher call the entire HEAT.R script:

```
vi HEAT.R # adapt the assessment period variable
Rscript HEAT.R
```

Or you can call the various separate bash scripts:

Note: Only the assessment period has to be specified. Paths to inputs and outputs are hard-coded, please modify them if applicable.

```
cd src
./run_heat1.sh 2011-2016
./run_heat2.sh 2011-2016
./run_heat3.sh 2011-2016
./run_heat4.sh 2011-2016
./run_heat5.sh 2011-2016

# for the plots:
./plot_annual_indicator_barcharts.sh
./plot_assessment_indicator_maps.sh
./plot_status_maps.sh
```

What the bash scripts do is basically they call separate R scripts and pass the paths to the inputs and outputs to them:

```
cd src

Rscript run_heat1.R "2011-2016" "../Input/2011-2016/AssessmentUnits.shp" "../Input/2011-2016/Configuration2011-2016.xlsx" "../testoutputs/units_cleaned2011-2016.shp" "../testoutputs/units_gridded2011-2016.shp" "../testoutputs/"

Rscript run_heat2.R "../Input/2011-2016/StationSamples2011-2016BOT_2022-12-09.txt.gz" "../Input/2011-2016/StationSamples2011-2016CTD_2022-12-09.txt.gz" "../Input/2011-2016/StationSamples2011-2016PMP_2022-12-09.txt.gz" "../testoutputs/units_gridded2011-2016.shp" "../testoutputs/StationSamples2011-2016BOT.csv" "../testoutputs/StationSamples2011-2016CTD.csv" "../testoutputs/StationSamples2011-2016PMP.csv" "../testoutputs/StationSamples2011-2016.csv"

Rscript run_heat3.R "../testoutputs/StationSamples2011-2016.csv" "../testoutputs/units_cleaned2011-2016.shp" "../Input/2011-2016/Configuration2011-2016.xlsx" "true" "../testoutputs/AnnualIndicators2011-2016.csv"

Rscript run_heat4.R "../testoutputs/AnnualIndicators2011-2016.csv" "../Input/2011-2016/Configuration2011-2016.xlsx" "../testoutputs/AssessmentIndicators2011-2016.csv"

Rscript run_heat5.R "../testoutputs/AssessmentIndicators2011-2016.csv" "../Input/2011-2016/Configuration2011-2016.xlsx" "../testoutputs/Assessment2011-2016.csv"

# Similar for the plots...
```

### Configuration: XLSX and CSV

Originally, an Excel document with four sheets was provided that contained
necessary configuration for the analysis:

* `Configuration2016-2021`

(A fifth sheet exists, but does not seem to be used in the analysis).

The modularized functions can also work with the same data as four different
CSV files (semicolon-separated):

* `Configuration2016-2021_Indicators.csv`
* `Configuration2016-2021_IndicatorUnitResults.csv`
* `Configuration2016-2021_IndicatorUnits.csv`
* `Configuration2016-2021_UnitGridSize.csv`

For this, reading the configuration was put into four functions, which accept an
optional parameter `format="xlsx"` or `format="csv"`:

* `get_indicators_table()`
* `get_indicator_units_table()`
* `get_indicator_unit_results_table()`
* `get_unit_grid_size_table()`


Note: I did not add the CSV files to this repository, as the original Excel document
also is not included. But they can easily be generated from the Excel document.

Obviously, when using four different files instead of one, more paths have to be passed.
As examples, R and bash scripts that work with the CSV files are included in `src`, e.g.
`run_heat3_csv.R` and `run_heat3_csv.sh` instead of `run_heat3.R` and `run_heat3.sh`.

