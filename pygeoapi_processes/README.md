# Pygeoapi Processes

## What is this about?

TODO


## How to run such a process?

When they are installed on server `example.com`, you can run them via HTTP POST requests, for example, using curl:

```
curl -X POST 'https://example.com/pygeoapi/processes/heat2/execution' \
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

The process descriptions provide you will information on the parameters.

Check out [https://example.com/pygeoapi/processes?f=html](https://example.com/pygeoapi/processes?f=html) for an HTML description of the available tools, their input and outputs.


## What do they do?

Currently, you can only reproduce the existing HOLAS analysis, in 5 steps.

For the three available HOLAS assessment periods, spatial units and configuration (e.g. grid size) are provided on the server.


### heat1

Compute the assessment units for the HEAT assessment tool. The area is gridded, the grid cells have different sizes in different regions.

All you can specify is the assessment period ("holas-2", "holas-3", "other").

The tool will pick the corresponding HELCOM spatial units, and the corresponding grid sizes, and generate two outputs:

* A cleaned version of the spatial units (filtered SEA units, some added stations, assign unit ids, ... check the R code or ask HELCOM for more details!)
* The gridded file

TODO: Eventually we could provide the plotted PNGs here.


### heat2

Combine the samples from three types of samples into one file.

All you can specify is the assessment period ("holas-2", "holas-3", "other"), and for each sample type, whether the default data should be used
(then provide the word "default" for that parameter) or none at all (leave parameter out).

The tool will pick the corresponding gridded HELCOM spatial units (precomputed, see above), and the default sample data (bottle, pump, ctd) and generate these outputs:

* combined station samples as CSV
* the used bottle station samples
* the used ctd station samples
* the used pump station samples

Note that if you leave all three out, the tool will fail, as it cannot run without any data, obviously.

TODO: Let users provide their own bottle samples, downloaded from ICES!


## How to install ... ?

TODO
