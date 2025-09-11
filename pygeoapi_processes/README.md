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


### Prerequisites

* Existing pygeoapi instance on a Linux server (ideally running behind a reverse proxy taking care of SSL termination)
* Docker must be installed
* We assume that you can start and stop the pygeoapi instance using `systemctl` (convenient but not stricly necessary)
* If you want to be able for users to download the results, you need a directory that is exposed to the web (e.g. `/var/www/nginx/download`) via some webserver (e.g. `nginx`).


### Clone repo

In an existing pygeoapi installation (`/opt/pygeoapi/`), go to the directory `pygeoapi/process`. Clone this directory there and switch to branch `aquabranch_pygeoapi`.

```
cd /opt/my-instance
cd pygeoapi/pygeoapi/process/
git clone https://github.com/AquaINFRA/HEAT.git
cd HEAT
git checkout aquabranch_pygeoapi
```

Install requirements:

```
# important: activate virtual env if your pygeoapi runs in one (it should!)
source /opt/my-instance/venv3/bin/activate

pip install -r requirements-heat.txt
```

### Add to config

Add the processes to the `pygeoapi-config.yml`:

```
cd /opt/my-instance
cd pygeoapi/
vi pygeoapi-config.yml
```

Under section `resources`, add the processes:

```
resources:

    ...
    ...

    hello-world:
        type: process
        processor:
          name: HelloWorld

    ...

    heat1:
        type: process
        processor:
            name: HEAT1Processor

    heat2:
        type: process
        processor:
            name: HEAT2Processor

    heat3:
        type: process
        processor:
            name: HEAT3Processor

    heat4:
        type: process
        processor:
            name: HEAT4Processor

    heat5:
        type: process
        processor:
            name: HEAT5Processor

    # HELCOM
    heat1advanced:
        type: process
        processor:
            name: HEAT1ProcessorA

    heat2advanced:
        type: process
        processor:
            name: HEAT2ProcessorA
   
    heat3advanced:
        type: process
        processor:
            name: HEAT3ProcessorA
    
    heat4advanced:
        type: process
        processor:
            name: HEAT4ProcessorA
    
    heat5advanced:
        type: process
        processor:
            name: HEAT5ProcessorA
```

Also add them to `plugin.py`:

```
cd /opt/my-instance
cd pygeoapi/
vi pygeoapi/plugin.py
```

In section `process`:

```
...
    'process': {
        'HelloWorld': 'pygeoapi.process.hello_world.HelloWorldProcessor',
        'HEAT1Processor': 'pygeoapi.process.HEAT.pygeoapi_processes.heat1.HEAT1Processor',
        'HEAT2Processor': 'pygeoapi.process.HEAT.pygeoapi_processes.heat2.HEAT2Processor',
        'HEAT3Processor': 'pygeoapi.process.HEAT.pygeoapi_processes.heat3.HEAT3Processor',
        'HEAT4Processor': 'pygeoapi.process.HEAT.pygeoapi_processes.heat4.HEAT4Processor',
        'HEAT5Processor': 'pygeoapi.process.HEAT.pygeoapi_processes.heat5.HEAT5Processor',
        'HEAT1ProcessorA': 'pygeoapi.process.HEAT.pygeoapi_processes.heat1_advanced.HEAT1Processor',
        'HEAT2ProcessorA': 'pygeoapi.process.HEAT.pygeoapi_processes.heat2_advanced.HEAT2Processor',
        'HEAT3ProcessorA': 'pygeoapi.process.HEAT.pygeoapi_processes.heat3_advanced.HEAT3Processor',
        'HEAT4ProcessorA': 'pygeoapi.process.HEAT.pygeoapi_processes.heat4_advanced.HEAT4Processor',
        'HEAT5ProcessorA': 'pygeoapi.process.HEAT.pygeoapi_processes.heat5_advanced.HEAT5Processor',
        ...
    }
```


Also, some config needs to be added to `config.json`. If it exists, add just the HEAT-specific section:


```
cd /opt/my-instance
vi pygeoapi/config.json

# Add:
{
    ...
    "helcom_heat": {
        "input_dir": "/var/www/nginx/download/readonly/helcom",
        "download_whitelist": ["igb-berlin.de", "helcom.fi", "ices.dk", "google.com"]
    }
}
```

Otherwise, fill it in entirely:

```
{
    "download_dir": "/var/www/nginx/download/",
    "docker_executable": "/usr/bin/docker",
    "download_url": "https://aquainfra.ogc.igb-berlin.de/download/",
    "helcom_heat": {
        "input_dir": "/var/www/nginx/download/readonly/helcom",
        "download_whitelist": ["igb-berlin.de", "helcom.fi", "ices.dk", "google.com"]
    }
}
```


### Reinstall

Re-install pygeoapi, so it knows how to find those additional modules:

```
# important: activate virtual env if your pygeoapi runs in one (it should!)
source /opt/my-instance/venv3/bin/activate

# Then install, with or without "-e"
cd /opt/my-instance
cd pygeoapi/
pip install -e .
```


### Build docker image

Using the `Dockerfile` contained in this repo, build a Docker image that will be run for each of the processes.
Please note that the name of the image has to correspond to the image in 

```
cd /opt/my-instance/
cd pygeoapi/pygeoapi/process/HEAT/
grep -r "self\.image_name"   # to see which image name is expected
date; docker build -t heat:latest .
date; docker build -t <expected-image-name> .
```


### Recreate the openapi definition file

```
# important: activate virtual env if your pygeoapi runs in one (it should!)
source /opt/my-instance/venv3/bin/activate

cd /opt/my-instance/
cd pygeoapi/
export PYGEOAPI_CONFIG=pygeoapi-config.yml
export PYGEOAPI_OPENAPI=pygeoapi-openapi.yml
pygeoapi openapi generate $PYGEOAPI_CONFIG --output-file $PYGEOAPI_OPENAPI
```

### Restart

```
# Restart the server:
sudo systemctl restart pygeoapi
```

### Check if it's running

With a browser: https://<your-url>/pygeoapi/processes?f=html 

With curl: `curl https://<your-url>/pygeoapi/processes?f=json`

Test a simple process:

```
curl -X POST 'https://<your-url>/pygeoapi/processes/heat1/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "assessment_period": "holas-2"
    }
}'
```

The response should look similar to this:

```
{
    "outputs":{
        "units_gridded":{
            "title":"Gridded assessment units",
            "description":"Grid used for confidence assessment (10k ,30k, 60k).",
            "href":"https://.../units_gridded-8e8f08a7-8f1c-11f0-a0ae-fa163e42fba0.zip",
            ...
        },
        "units_cleaned":{
            "title":"Non-gridded assessment units",
            "description":"Non-gridded Assessment units which were cleaned, slightly adapted (e.g. some stations added manually), and extended (e.g. with the units's area and a UnitID). This will not be used further on and is rather a by-product, an intermediate step before gridding the data.",
            "href":"https://.../units_cleaned-8e8f08a7-8f1c-11f0-a0ae-fa163e42fba0.zip"
        }
    }
}
```

Done!