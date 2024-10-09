# HEAT as OGC API processes (AquaINFRA project)

## What is the AquaINFRA project?

Read here: https://aquainfra.eu/

## What are OGC processes?

... TODO Write or find a quick introduction ...

Read here: https://ogcapi.ogc.org/

## WHat is pygeoapi?

...TODO...

Read here: https://pygeoapi.io/

## Steps to deploy this as OGC processes

* Make sure R is running on your machine.
* Deploy an instance of pygeoapi (https://pygeoapi.io/). We will assume it is running on `localhost:5000`.
* Go to the `process` directory of your installation, i.e. `cd /.../pygeoapi/pygeoapi/process`.
* Clone this repo and checkout this branch
* Open the `plugin.py` file (`vi /.../pygeoapi/pygeoapi/plugin.py`) and add these lines to the `'process'` section:

```
    'process': {
        'HelloWorld': 'pygeoapi.process.hello_world.HelloWorldProcessor',
        ...
        'HEAT1Processor': 'pygeoapi.process.HEAT.heat_1.HEAT1Processor',
        'HEAT2Processor': 'pygeoapi.process.HEAT.heat_2.HEAT2Processor',
        'HEAT3Processor': 'pygeoapi.process.HEAT.heat_3.HEAT3Processor',
        'HEAT4Processor': 'pygeoapi.process.HEAT.heat_4.HEAT4Processor',
        'HEAT5Processor': 'pygeoapi.process.HEAT.heat_5.HEAT5Processor',
        ...
```

* Open the `pygeoapi-config.yaml` file (`vi /.../pygeoapi/pygeoapi-config.yaml`) and add these lines to the `resources` section:

```
resources:

    ...

    heat_1:
        type: process
        processor:
            name: HEAT1Processor

    heat_2:
        type: process
        processor:
            name: HEAT2Processor

    heat_3:
        type: process
        processor:
            name: HEAT3Processor

    heat_4:
        type: process
        processor:
            name: HEAT4Processor

    heat_5:
        type: process
        processor:
            name: HEAT5Processor

```

* Config file: Make sure you have a `config.json` sitting either in pygeoapi's current working dir (`...TODO...`) or in an arbitrary path that pygeoapi can find through the environment variable `HELCOM_CONFIG_FILE`.
* When running with flask or starlette, you can add that env var by adding the line `os.environ['HELCOM_CONFIG_FILE'] = '/.../config.json'` to `/.../pygeoapi/pygeoapi/starlette_app.py`
* Make sure this config file contains:

```
{
	...
	"helcom_heat": {
        "r_script_dir": "/pygeoapi/pygeoapi/process/HEAT/pygeoapi_processes/r_scripts"
        "input_path":"/.../inputs",
        "intermediate_dir":"/tmp/",
        "download_dir": "/var/www/nginx/download/",
        "download_url": "https://testserver.com/download/",
    },
    ...
}
```

* Downloading of results:
** If you don't need this right now, just put any writeable path into `download_dir`, where you want the results to be written. Put some dummy value into `download_url`.
** If you want users to be able to download results from remote, have some webserver running (e.g. `nginx` or `apache2`) that you can use to serve static files. The directory for the static results and the URL where that is reachable have to be written into `download_dir` and `download_url`.
* Make sure to create a directory for inputs, add HELCOM's inputs to there, and write it into `input_path` of the config file:

```
ls -1 /opt/pyg_upstream_dev/pygeoapi/pygeoapi/process/HEAT_inputs
1877-9999
2011-2016
2016-2021
ls -1 /opt/pyg_upstream_dev/pygeoapi/pygeoapi/process/HEAT_inputs/1877-9999/
Configuration1877-9999_IndicatorUnitResults.csv
Configuration1877-9999_IndicatorUnits.csv
Configuration1877-9999_Indicators.csv
Configuration1877-9999_UnitGridSize.csv
Configuration1877-9999_Units.csv
# TODO some missing here? TODO source? Aren't they on GitHub?
ls -1 /opt/pyg_upstream_dev/pygeoapi/pygeoapi/process/HEAT_inputs/2011-2016/
Configuration2011-2016_IndicatorUnitResults.csv
Configuration2011-2016_IndicatorUnits.csv
Configuration2011-2016_Indicators.csv
Configuration2011-2016_UnitGridSize.csv
Configuration2011-2016_Units.csv
# TODO some missing here? TODO source? Aren't they on GitHub?
ls -1 /opt/pyg_upstream_dev/pygeoapi/pygeoapi/process/HEAT_inputs/2016-2021/
Configuration2016-2021_IndicatorUnitResults.csv
Configuration2016-2021_IndicatorUnits.csv
Configuration2016-2021_Indicators.csv
Configuration2016-2021_UnitGridSize.csv
Configuration2016-2021_Units.csv
HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022_eutro.cpg
HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022_eutro.dbf
HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022_eutro.prj
HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022_eutro.sbn
HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022_eutro.sbx
HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022_eutro.shp
HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022_eutro.shx
StationSamples2016-2021BOT_2022-12-09.txt.gz
StationSamples2016-2021CTD_2022-12-09.txt.gz
StationSamples2016-2021PMP_2022-12-09.txt.gz
# TODO source? Aren't they on GitHub?
```

* Install the following R packages: `tidyverse`, `R.utils` (TODO: any others?)
* Start pygeoapi following their documentation



