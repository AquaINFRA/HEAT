# HTTP Requests and Responses for HELCOM HEAT processes (reproduction of HOLAS assessment periods)

Merret, 2025-07-07

List of processes: http://localhost:5000/processes?f=html

These processes use predefined configurations defined by HELCOM for the various HOLAS assessment periods (holas-2, holas-3, other).

It can also use predefined default data defined by HELCOM, but you can also provide your own input bottle, CTD or pump data.


## heat1 (generating the gridded spatial units)

* Description: http://localhost:5000/processes/heat1
* This uses the definition of grid sizes defined by HELCOM.
* (In the more custom version of heat1, you can provide the grid sizes as a csv table (grid_size_table)).


### Test inputs

Does not apply - the input files are static and stored on the server.


### Example request and response

Request:

```
curl -X POST 'http://localhost:5000/processes/heat1/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "assessment_period": "holas-2"
    }
}'
```

Response:

```
{
    "outputs":{
        "units_gridded":{
            "title":"Gridded assessment units",
            "description":"Grid used for confidence assessment (10k ,30k, 60k).",
            "href":"http://ourserver.de/download/out/units_gridded-01321a30-5b08-11f0-888a-fa163e42fba0.zip",
            "href_geojson":"http://ourserver.de/download/out/units_gridded-01321a30-5b08-11f0-888a-fa163e42fba0.json",
            "href_viewer":"http://ourserver.de/viewer.html?filebase=units_gridded&job_id=01321a30-5b08-11f0-888a-fa163e42fba0"
        },
        "units_cleaned":{
            "title":"Non-gridded assessment units",
            "description":"Non-gridded Assessment units which were cleaned, slightly adapted (e.g. some stations added manually), and extended (e.g. with the units's area and a UnitID). This will not be used further on and is rather a by-product, an intermediate step before gridding the data.",
            "href":"http://ourserver.de/download/out/units_cleaned-01321a30-5b08-11f0-888a-fa163e42fba0.zip"
        }
    }
```

## heat2 (combining the samples)

* Description: http://localhost:5000/processes/heat2
* This uses the gridded spatial units defined by HELCOM.
* (In the more custom version of heat2, you can provide the grid units that you generated yourself, as a zipped shapefile (units_gridded)).

### Test inputs

The input data from the HOLAS assessments can be found here, if you want to use them for testing - these are also what is used as default for the various assessment periods.

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


### Example request and response (using HELCOM defaults)

Request (using default data for all three sample types):

```
curl -X POST 'http://localhost:5000/processes/heat2/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "assessment_period": "holas-2",
        "bottle_data": "default",
        "pump_data": "default",
        "ctd_data": "default"
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
            "href":"http://ourserver.de/download/out/StationSamples-d2bbd6f1-5b1c-11f0-a174-fa163e42fba0.csv",
            "href_geojson":"http://ourserver.de/download/out/StationSamples-d2bbd6f1-5b1c-11f0-a174-fa163e42fba0.json",
            "href_viewer":"http://ourserver.de/viewer.html?filebase=StationSamples&job_id=d2bbd6f1-5b1c-11f0-a174-fa163e42fba0"
        },
        "bottle_samples":{
            "title":"Station samples (bottle), filtered",
            "description":"In-situ bottle sample data (nutrients, chl-a), ICES Oceanographic data type 'BOT'. Filtered by the spatial units for HOLAS assessment. This will not be used further on and is rather a by-product that you may use for progress verification.",
            "href":"http://ourserver.de/download/out/StationSamplesBOT-d2bbd6f1-5b1c-11f0-a174-fa163e42fba0.csv"
        },
        "pump_samples":{
            "title":"Station samples (pump), filtered",
            "description":"Ferrybox data (chl-a) (StationSamplesPMP.csv), ICES Oceanographic data type 'PMP'. Filtered by the spatial units for HOLAS assessment. This will not be used further on and is rather a by-product that you may use for progress verification.",
            "href":"http://ourserver.de/download/out/StationSamplesPMP-d2bbd6f1-5b1c-11f0-a174-fa163e42fba0.csv"
        },
        "ctd_samples":{
            "title":"Station samples (CTD), filtered",
            "description":" CTD depth profiles, relevant for oxygen debt indicator, ICES Oceanographic data type 'CTD'. Filtered by the spatial units for HOLAS assessment. This will not be used further on and is rather a by-product that you may use for progress verification.",
            "href":"http://ourserver.de/download/out/StationSamplesCTD-d2bbd6f1-5b1c-11f0-a174-fa163e42fba0.csv"
        },
        "units_gridded":{
            "title":"Gridded assessment units",
            "description":"Grid used for confidence assessment (10k ,30k, 60k), which was used for this process.  This will not be used further on and is rather a by-product that you may use for progress verification.",
            "href":null
        }
    }
}
```


### Example request (using HELCOM defaults, bottle only)

You can omit CTD and pump data and only use bottle data:

```
curl -X POST 'http://localhost:5000/processes/heat2/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "assessment_period": "holas-2",
        "bottle_data": "default"
    }
}'
```

### Example request (using custom bottle data)

You can omit CTD and pump data and use custom bottle data, which you have downloaded from ICES and places on some server:

```
curl -X POST 'http://localhost:5000/processes/heat2/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "assessment_period": "holas-2",
        "bottle_data": "http://ourserver.de/download/readonly/helcom/ices_example/7908cc01-42d4-460c-8b47-c960f97191ef.csv"
    }
}'
```

## heat3 (computing the Annual Indicators)

* Description: http://localhost:5000/processes/heat3
* As input parameter "station_samples", provide the output from heat2.
* You can test with "true" or "false" for the chlorophyll thing, but I have no idea what that does...
* This uses the configuration tables defined by HELCOM (indicators, indicator units, indicator unit results).
* (In the more custom version of heat3, you can provide those as csv tables.)


### Test inputs

Does not apply (only output from last process needed).


### Example request and response

Request:

```
curl -X POST 'http://localhost:5000/processes/heat3/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "assessment_period": "holas-2",
        "station_samples": "http://ourserver.de/download/out/StationSamples-d2bbd6f1-5b1c-11f0-a174-fa163e42fba0.csv",
        "combined_Chlorophylla_IsWeighted": true
    }
}'
```

Response:

```
{
    "outputs":{
        "annual_indicators":{
            "title":"Annual Indicators Table",
            "description":"CSV file of calculated HEAT EQRS per indicator per year per assessment unit (AnnualIndicators.csv).",
            "href":"http://ourserver.de/download/out/AnnualIndicators-669a7a6b-5b1d-11f0-8c02-fa163e42fba0.csv"
        }
    }
}
```

## heat4 (computing Assessment Indicators)

* Description: http://localhost:5000/processes/heat4
* As input parameter "annual_indicators", provide the output from heat3.
* This uses the configuration tables defined by HELCOM (indicators, indicator units).
* (In the more custom version of heat4, you can provide those as csv tables.)


### Test inputs

Does not apply (only output from last process needed).


### Example request and response

Request:

```
curl -X POST 'http://localhost:5000/processes/heat4/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "assessment_period": "holas-2",
        "annual_indicators": "http://ourserver.de/download/out/AnnualIndicators-669a7a6b-5b1d-11f0-8c02-fa163e42fba0.csv"
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
            "href":"http://ourserver.de/download/out/AssessmentIndicators-fd6478a7-5b1d-11f0-b76c-fa163e42fba0.csv"
        }
    }
}
```

## heat5 (computing the Assessment)

* Description: http://localhost:5000/processes/heat5
* As input parameter "assessment_indicators", provide the output from heat4.
* This uses the configuration tables defined by HELCOM (indicators, indicator units).
* (In the more custom version of heat5, you can provide those as csv tables.)


### Test inputs

Does not apply (only output from last process needed).


### Example request and response

Request:

```
curl -X POST 'http://localhost:5000/processes/heat5/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "assessment_period": "holas-2",
        "assessment_indicators": "http://ourserver.de/download/out/AssessmentIndicators-fd6478a7-5b1d-11f0-b76c-fa163e42fba0.csv"
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
            "href":"http://ourserver.de/download/out/Assessment-29b7b010-5b1e-11f0-9f23-fa163e42fba0.csv"
        }
    }
}
```

That's it for reproduction of HOLAS assessment units!

