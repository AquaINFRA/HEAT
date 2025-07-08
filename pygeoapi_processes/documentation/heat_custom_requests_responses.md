# HTTP Requests and Responses for HELCOM HEAT processes (customizable)

Merret, 2025-07-07

List of processes: http://localhost:5000/processes?f=html

These processes allow users to use their own spatial units and configurations. No defaults are provided. Please let me know if any defaults are desired.


## heat1advanced (generating the gridded spatial units)

* Description: http://localhost:5000/processes/heat1advanced
* You have to provide your own spatial units (zipped shape), as no defaults are provided. It needs to have a column "UnitID", and the values in that column need to match the column in the grid size table.
* You have to provide your own grid size table, matching the UnitIDs of the spatial units, as no defaults are provided.

### Test inputs

* I manually drew two polygons using QGIS and stored them as shapefile to serve as dummy test spatial units (placed on our server as test data: http://ourserver.de/exampledata/helcom/dummy/dummytest_epsg4326_unitid.zip). 
* I created a dummy grid size table (placed on our server as test data: http://ourserver.de/exampledata/helcom/dummy/Configuration_dummy_UnitGridSize.csv):


Content of the dummy grid size table:

```
curl http://ourserver.de/exampledata/helcom/dummy/Configuration_dummy_UnitGridSize.csv
UnitID;GridSize
9;80000
99;40000
999;20000
4;120000
5;120000
```


### Example request and response

Request:

```
curl -X POST 'http://localhost:5000/processes/heat1advanced/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "spatial_units": "http://ourserver.de/exampledata/helcom/dummy/dummytest_epsg4326_unitid.zip",
        "grid_size_table": "http://ourserver.de/exampledata/helcom/dummy/Configuration_dummy_UnitGridSize.csv"
    }
}'
```

Response:

```
{
    "outputs":{
        "units_gridded":{
            "title":"Gridded assessment units",
            "description":"Grid to be used for confidence assessment.",
            "href":"http://ourserver.de/download/out/units_gridded-0383d054-5b28-11f0-bea1-fa163e42fba0.zip",
            "href_geojson":"http://ourserver.de/download/out/units_gridded-0383d054-5b28-11f0-bea1-fa163e42fba0.json",
            "href_viewer":"http://ourserver.de/viewer.html?filebase=units_gridded&job_id=0383d054-5b28-11f0-bea1-fa163e42fba0"
        },
        "units_cleaned":{
            "title":"Cleaned assessment units",
            "description":"The units, filtered, transformed to EPSG 3035.",
            "href":"http://ourserver.de/download/out/units_cleaned-0383d054-5b28-11f0-bea1-fa163e42fba0.zip"
        }
    }
}
```

## heat2advanced (combining the samples)

* Description: http://localhost:5000/processes/heat2advanced
* You have to provide your own gridded spatial units (parameter "units_gridded"), as no defaults are provided. Use the output of heat1advanced for this.
* As input "bottle_data", "pump_data", "ctd_data", provide whatever samples you want to use. (Currently, all three types HAVE to be provided by the user - if you prefer that we provide defaults, or if you want users to be able to leave some types empty, let me know).

### Test inputs

The input data from the HOLAS assessments can be found here, if you want to use them for testing:

* http://ourserver.de/download/readonly/helcom/original_inputs/2011-2016/StationSamples2011-2016BOT_2022-12-09.txt.gz
* http://ourserver.de/download/readonly/helcom/original_inputs/2011-2016/StationSamples2011-2016CTD_2022-12-09.txt.gz
* http://ourserver.de/download/readonly/helcom/original_inputs/2011-2016/StationSamples2011-2016PMP_2022-12-09.txt.gz
* http://ourserver.de/download/readonly/helcom/original_inputs/2016-2021/StationSamples2016-2021BOT_2022-12-09.txt.gz
* http://ourserver.de/download/readonly/helcom/original_inputs/2016-2021/StationSamples2016-2021CTD_2022-12-09.txt.gz
* http://ourserver.de/download/readonly/helcom/original_inputs/2016-2021/StationSamples2016-2021PMP_2022-12-09.txt.gz
* http://ourserver.de/download/readonly/helcom/original_inputs/1877-9999/StationSamples1877-9999BOT_2022-12-09.txt.gz
* http://ourserver.de/download/readonly/helcom/original_inputs/1877-9999/StationSamples1877-9999CTD_2022-12-09.txt.gz
* http://ourserver.de/download/readonly/helcom/original_inputs/1877-9999/StationSamples1877-9999PMP_2022-12-09.txt.gz

I uploaded two CSV files that I downloaded from ICES, to test the functioning with ICES data. I think it should be used as bottle data.

* http://ourserver.de/download/readonly/helcom/ices_example/7908cc01-42d4-460c-8b47-c960f97191ef.csv
* http://ourserver.de/download/readonly/helcom/ices_example/755abc4a-4534-4f72-8a48-1496efd2f487.csv


### Example request and response (using HELCOM inputs)

Request using HELCOM inputs:

```
curl -X POST 'http://localhost:5000/processes/heat2advanced/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "units_gridded": "http://ourserver.de/download/out/units_gridded-0383d054-5b28-11f0-bea1-fa163e42fba0.zip",
        "bottle_data": "http://ourserver.de/download/readonly/helcom/original_inputs/2016-2021/StationSamples2016-2021BOT_2022-12-09.txt.gz",
        "pump_data": "http://ourserver.de/download/readonly/helcom/original_inputs/2011-2016/StationSamples2011-2016PMP_2022-12-09.txt.gz",
        "ctd_data": "http://ourserver.de/download/readonly/helcom/original_inputs/2016-2021/StationSamples2016-2021CTD_2022-12-09.txt.gz"
    }
}'
```

Response:

```
{
    "outputs":{
        "station_samples":{
            "title":"Station samples (filtered, combined)",
            "description":"Merged sample data of BOT, PMP and CTD data for indicator calculation (StationSamples.csv).",
            "href":"http://ourserver.de/download/out/StationSamples-e05d05d6-5b3e-11f0-9a44-fa163e42fba0.csv",
            "href_geojson":"http://ourserver.de/download/out/StationSamples-e05d05d6-5b3e-11f0-9a44-fa163e42fba0.json",
            "href_viewer":"http://ourserver.de/viewer.html?filebase=StationSamples&job_id=e05d05d6-5b3e-11f0-9a44-fa163e42fba0"
        },
        "bottle_samples":{
            "title":"Station samples (bottle), filtered",
            "description":"In-situ bottle sample data (nutrients, chl-a), ICES Oceanographic data type 'BOT'. Filtered by the specified spatial units. This will not be used further on and is rather a by-product that you may use for progress verification.",
            "href":"http://ourserver.de/download/out/StationSamplesBOT-e05d05d6-5b3e-11f0-9a44-fa163e42fba0.csv"
        },
        "pump_samples":{
            "title":"Station samples (pump), filtered",
            "description":"Ferrybox data (chl-a) (StationSamplesPMP.csv), ICES Oceanographic data type 'PMP'. Filtered by the specified spatial units. This will not be used further on and is rather a by-product that you may use for progress verification.",
            "href":"http://ourserver.de/download/out/StationSamplesPMP-e05d05d6-5b3e-11f0-9a44-fa163e42fba0.csv"
        },
        "ctd_samples":{
            "title":"Station samples (CTD), filtered",
            "description":" CTD depth profiles, relevant for oxygen debt indicator, ICES Oceanographic data type 'CTD'. Filtered by the specified spatial units. This will not be used further on and is rather a by-product that you may use for progress verification.",
            "href":"http://ourserver.de/download/out/StationSamplesCTD-e05d05d6-5b3e-11f0-9a44-fa163e42fba0.csv"
        }
    }
}
```

### Example request and response (using ICES bottle data)

Request:

```
curl -X POST 'http://localhost:5000/processes/heat2advanced/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "units_gridded": "http://ourserver.de/download/out/units_gridded-0383d054-5b28-11f0-bea1-fa163e42fba0.zip",
        "bottle_data": "http://ourserver.de/download/readonly/helcom/ices_example/755abc4a-4534-4f72-8a48-1496efd2f487.csv",
        "pump_data": "http://ourserver.de/download/readonly/helcom/original_inputs/2011-2016/StationSamples2011-2016PMP_2022-12-09.txt.gz",
        "ctd_data": "http://ourserver.de/download/readonly/helcom/original_inputs/2016-2021/StationSamples2016-2021CTD_2022-12-09.txt.gz"
    }
}'
```

Response:

```
{
    "outputs":{
        "station_samples":{
            "title":"Station samples (filtered, combined)",
            "description":"Merged sample data of BOT, PMP and CTD data for indicator calculation (StationSamples.csv).",
            "href":"http://ourserver.de/download/out/StationSamples-2f0c6c02-5b41-11f0-a5bd-fa163e42fba0.csv",
            "href_geojson":"http://ourserver.de/download/out/StationSamples-2f0c6c02-5b41-11f0-a5bd-fa163e42fba0.json",
            "href_viewer":"http://ourserver.de/viewer.html?filebase=StationSamples&job_id=2f0c6c02-5b41-11f0-a5bd-fa163e42fba0"
        },
        "bottle_samples":{
            "title":"Station samples (bottle), filtered",
            "description":"In-situ bottle sample data (nutrients, chl-a), ICES Oceanographic data type 'BOT'. Filtered by the specified spatial units. This will not be used further on and is rather a by-product that you may use for progress verification.",
            "href":"http://ourserver.de/download/out/StationSamplesBOT-2f0c6c02-5b41-11f0-a5bd-fa163e42fba0.csv"
        },
        "pump_samples":{
            "title":"Station samples (pump), filtered",
            "description":"Ferrybox data (chl-a) (StationSamplesPMP.csv), ICES Oceanographic data type 'PMP'. Filtered by the specified spatial units. This will not be used further on and is rather a by-product that you may use for progress verification.",
            "href":"http://ourserver.de/download/out/StationSamplesPMP-2f0c6c02-5b41-11f0-a5bd-fa163e42fba0.csv"
        },
        "ctd_samples":{
            "title":"Station samples (CTD), filtered",
            "description":" CTD depth profiles, relevant for oxygen debt indicator, ICES Oceanographic data type 'CTD'. Filtered by the specified spatial units. This will not be used further on and is rather a by-product that you may use for progress verification.",
            "href":"http://ourserver.de/download/out/StationSamplesCTD-2f0c6c02-5b41-11f0-a5bd-fa163e42fba0.csv"
        }
    }
}
```



## heat3advanced (computing the Annual Indicators)

* Description: http://localhost:5000/processes/heat3advanced
* As input parameter "station_samples", provide the output from heat2advanced.
* You have to provide your own (un-gridded) spatial units (parameter "spatial_units"), as no defaults are provided. Use the output of heat1advanced for this.
* You have to provide your own configuration tables (indicators, indicator units, indicator unit results), as no defaults are provided.

### Test inputs

These are dummy configuration tables I created for testing:

* http://ourserver.de/exampledata/helcom/dummy/Configuration_dummy_IndicatorUnitResults.csv
* http://ourserver.de/exampledata/helcom/dummy/Configuration_dummy_IndicatorUnits.csv
* http://ourserver.de/exampledata/helcom/dummy/Configuration_dummy_Indicators.csv
* http://ourserver.de/exampledata/helcom/dummy/Configuration_dummy_UnitGridSize.csv
* http://ourserver.de/exampledata/helcom/dummy/Configuration_dummy_Units.csv

### Example request and response

Request (using the station samples generated with only HEAT input)

```
curl -X POST 'http://localhost:5000/processes/heat3advanced/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "station_samples": "http://ourserver.de/download/out/StationSamples-e05d05d6-5b3e-11f0-9a44-fa163e42fba0.csv",
        "spatial_units": "http://ourserver.de/download/out/units_cleaned-0383d054-5b28-11f0-bea1-fa163e42fba0.zip",
        "combined_Chlorophylla_IsWeighted": true,
        "table_indicators": "http://ourserver.de/exampledata/helcom/dummy/Configuration_dummy_Indicators.csv",
        "table_indicator_units": "http://ourserver.de/exampledata/helcom/dummy/Configuration_dummy_IndicatorUnits.csv",
        "table_indicator_unit_results": "http://ourserver.de/exampledata/helcom/dummy/Configuration_dummy_IndicatorUnitResults.csv"
    }
}'
```

You can test with "true" or "false" for the chlorophyll thing, but I have no idea what that does...

Response:

```
{
    "outputs":{
        "annual_indicators":{
            "title":"Annual Indicators Table",
            "description":"CSV file of calculated HEAT EQRS per indicator per year per assessment unit (AnnualIndicators.csv).",
            "href":"http://ourserver.de/download/out/AnnualIndicators-3cd979d2-5be9-11f0-8ab1-fa163e42fba0.csv"
        }
    }
}
```

## heat4advanced (computing Assessment Indicators)

* Description: http://localhost:5000/processes/heat4advanced
* As input parameter "annual_indicators", provide the output from heat3advanced.
* You have to provide your own configuration tables (indicators, indicator units), as no defaults are provided.

### Test inputs

See above for configuration tables.

### Example request and response

Request:

```
curl -X POST 'http://localhost:5000/processes/heat4advanced/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "annual_indicators": "http://ourserver.de/download/out/AnnualIndicators-3cd979d2-5be9-11f0-8ab1-fa163e42fba0.csv",
        "table_indicators": "http://ourserver.de/exampledata/helcom/dummy/Configuration_dummy_Indicators.csv",
        "table_indicator_units": "http://ourserver.de/exampledata/helcom/dummy/Configuration_dummy_IndicatorUnits.csv"
    }
}'
```

Response:

```
{
    "outputs":{
        "assessment_indicators":{
            "title":"Assessment Indicators Table",
            "description":"CSV file of calculated EQRS per assessment period per assessment unit (AssessmentIndicators.csv).",
            "href":"http://ourserver.de/download/out/AssessmentIndicators-b728dfe8-5be9-11f0-93da-fa163e42fba0.csv"
        }
    }
}
```

### heat5advanced (computing the Assessment)

* Description: http://localhost:5000/processes/heat5advanced
* As input parameter "assessment_indicators", provide the output from heat4advanced.
* You have to provide your own configuration tables (indicators, indicator units), as no defaults are provided.

### Test inputs

See above for configuration tables.

### Example request and response

Request:

```
curl -X POST 'http://localhost:5000/processes/heat5advanced/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "assessment_indicators": "http://ourserver.de/download/out/AssessmentIndicators-b728dfe8-5be9-11f0-93da-fa163e42fba0.csv",
        "table_indicators": "http://ourserver.de/exampledata/helcom/dummy/Configuration_dummy_Indicators.csv",
        "table_indicator_units": "http://ourserver.de/exampledata/helcom/dummy/Configuration_dummy_IndicatorUnits.csv"
    }
}'
```

Response:

```
{
    "outputs":{
        "assessment":{
            "title":"Assessment Table",
            "description":"CSV file: table of calculated EQRS per assessment unit, grouped by overall and criterial level indicators (Assessment.csv).",
            "href":"http://ourserver.de/download/out/Assessment-d0241034-5be9-11f0-8334-fa163e42fba0.csv"
        }
    }
}
```

That's it for customizable HEAT analysis!

