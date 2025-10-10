import logging
LOGGER = logging.getLogger(__name__)

import json
import requests
import os
import traceback
import pandas as pd
import geopandas as gpd
import shapely.geometry
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError
from pygeoapi.process.HEAT.pygeoapi_processes.docker_utils import run_docker_container2
from pygeoapi.process.HEAT.pygeoapi_processes.heat_utils import download_zipped_data
from pygeoapi.process.HEAT.pygeoapi_processes.heat_utils import zip_a_shapefile
from pygeoapi.process.HEAT.pygeoapi_processes.heat_utils import get_path_bottle_input_data
from pygeoapi.process.HEAT.pygeoapi_processes.heat_utils import get_path_ctd_input_data
from pygeoapi.process.HEAT.pygeoapi_processes.heat_utils import get_path_pmp_input_data
from pygeoapi.process.HEAT.pygeoapi_processes.heat_utils import get_path_default_gridded_units


'''
# Using default (static on server) for all three:
curl -X POST 'http://localhost:5000/processes/heat2/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "assessment_period": "holas-2",
        "bottle_data": "default",
        "pump_data": "default",
        "ctd_data": "default",
        "units_gridded": "default"
    }
}'

# Omitting PMP and CTD:
curl -X POST 'http://localhost:5000/processes/heat2/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "assessment_period": "holas-2",
        "bottle_data": "default"
    }
}'

# Omitting PMP and CTD, using external data for BOT:
curl -X POST 'http://localhost:5000/processes/heat2/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "assessment_period": "holas-2",
        "bottle_data": "https://example.com/download/StationSamplesBOT.txt.gz"
    }
}'

'''


# Process metadata and description
# Has to be in a JSON file of the same name, in the same dir! 
script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))



class HEAT2Processor(BaseProcessor):

    def __init__(self, processor_def):
        super().__init__(processor_def, PROCESS_METADATA)
        self.job_id = None
        self.process_id = self.metadata["id"]

        # Set config:
        config_file_path = os.environ.get('AQUAINFRA_CONFIG_FILE', "./config.json")
        with open(config_file_path, 'r') as config_file:
            config = json.load(config_file)
            self.download_dir = config["download_dir"].rstrip('/')
            self.download_url = config["download_url"].rstrip('/')
            self.inputs_read_only = config["helcom_heat"]["input_dir"].rstrip('/')
            self.docker_executable = config["docker_executable"]
            self.image_name = "heat:20251010"


    def set_job_id(self, job_id: str):
        self.job_id = job_id

    def __repr__(self):
        return f'<HEAT2Processor> {self.name}'


    def execute(self, data):
        LOGGER.info('Starting process HEAT 2!')
        try:
            mimetype, result = self._execute(data)
            return mimetype, result

        except Exception as e:
            LOGGER.error(e)
            print(traceback.format_exc())
            raise ProcessorExecuteError(e)


    def _execute(self, data):

        ##############
        ### Inputs ###
        ##############

        # Retrieve user inputs:
        assessment_period = data.get('assessment_period')
        unitsGriddedFileUrl = data.get('units_gridded', None)
        bot_url = data.get('bottle_data', None)
        ctd_url = data.get('ctd_data', None)
        pmp_url = data.get('pump_data', None)

        # Check user inputs:
        if assessment_period is None:
            raise ProcessorExecuteError('Missing parameter "assessment_period". Please provide a string.')

        # Check validity of argument:
        valid_assessment_periods = ["holas-2", "holas-3", "other"]
        assessment_period = assessment_period.lower()
        if not assessment_period in valid_assessment_periods:
            raise ValueError('assessment_period is "%s", must be one of: %s' % (assessment_period, valid_assessment_periods))

        # Assign years to selected assessment period:
        if assessment_period == 'holas-2':
            assessment_period = '2011-2016'
        elif assessment_period == 'holas-3':
            assessment_period = '2016-2021'
        elif assessment_period == 'other':
            assessment_period = '1877-9999'

        # Check data url
        if unitsGriddedFileUrl is None:
            raise ProcessorExecuteError('Missing parameter units_gridded". Please provide a URL or the word "default".')
        elif not (unitsGriddedFileUrl == "default" or unitsGriddedFileUrl.startswith('http')):
            raise ProcessorExecuteError('Malformed parameter units_gridded". Please provide a URL or the word "default".')


        ##################
        ### Input data ###
        ##################

        # Where to store input data (will be mounted read-write into container,
        # so that inside the container the input file can be downloaded into here):
        input_dir = f'{self.download_dir}/in/{self.process_id}_job_{self.job_id}'
        os.makedirs(input_dir, exist_ok=True)

        # Directory where static input data can be found (will be mounted readonly into container):
        readonly_dir = self.inputs_read_only

        ## If user provided input shapes, use them, else use pre-computed input shapes (they are always the same anyway):
        if unitsGriddedFileUrl == "default":
            in_unitsGriddedFilePath = get_path_default_gridded_units(assessment_period, readonly_dir)
        else:
            ## Downloading was moved into the R script that happens inside the R script!
            LOGGER.info('Client provided gridded spatial units: %s' % unitsGriddedFileUrl)
            in_unitsGriddedFilePath = unitsGriddedFileUrl

        # Provide path to default input data, or pass URL on to the R script inside the container
        # that will download them inside the container:
        in_stationSamplesBOTFilePath = get_path_bottle_input_data(assessment_period, bot_url, readonly_dir)
        in_stationSamplesCTDFilePath = get_path_ctd_input_data(assessment_period, ctd_url, readonly_dir)
        in_stationSamplesPMPFilePath = get_path_pmp_input_data(assessment_period, pmp_url, readonly_dir)


        ###############
        ### Outputs ###
        ###############

        # Where to store output data
        output_dir = f'{self.download_dir}/out/{self.process_id}_job_{self.job_id}'
        output_url = f'{self.download_url}/out/{self.process_id}_job_{self.job_id}'
        os.makedirs(output_dir, exist_ok=True)
        LOGGER.debug(f'All results will be stored     in: {output_dir}')
        LOGGER.debug(f'All results will be accessible in: {output_url}')

        # Where to store output data
        out_stationSamplesTableCSVFilePath = f'{output_dir}/StationSamples-{self.job_id}.csv'
        out_stationSamplesBOTFilePath      = f'{output_dir}/StationSamplesBOT-{self.job_id}.csv'
        out_stationSamplesCTDFilePath      = f'{output_dir}/StationSamplesCTD-{self.job_id}.csv'
        out_stationSamplesPMPFilePath      = f'{output_dir}/StationSamplesPMP-{self.job_id}.csv'

        # Where to access output data
        out_stationSamplesTableCSV_url = out_stationSamplesTableCSVFilePath.replace(self.download_dir, self.download_url)
        out_stationSamplesBOT_url      = out_stationSamplesBOTFilePath.replace(self.download_dir, self.download_url)
        out_stationSamplesCTD_url      = out_stationSamplesCTDFilePath.replace(self.download_dir, self.download_url)
        out_stationSamplesPMP_url      = out_stationSamplesPMPFilePath.replace(self.download_dir, self.download_url)


        ###########
        ### Run ###
        ###########

        # Actually call R script:
        script_name = 'run_heat2.R'
        r_args = [
            input_dir,
            in_stationSamplesBOTFilePath,
            in_stationSamplesCTDFilePath,
            in_stationSamplesPMPFilePath,
            in_unitsGriddedFilePath,
            out_stationSamplesBOTFilePath,
            out_stationSamplesCTDFilePath,
            out_stationSamplesPMPFilePath,
            out_stationSamplesTableCSVFilePath
        ]
        returncode, stdout, stderr, user_err_msg = run_docker_container2(
            self.docker_executable,
            self.image_name,
            script_name,
            input_dir,
            output_dir,
            readonly_dir,
            r_args
        )

        # Results:
        # * StationSamples
        # * StationSamplesBOT.csv
        # * StationSamplesCTD.csv
        # * StationSamplesPMP.csv

        # Return R error message if exit code not 0:
        if not returncode == 0:
            raise ProcessorExecuteError(user_msg = user_err_msg)

        ########################
        ### Generate GeoJSON ###
        ########################

        # Read spatial units from csv file:
        LOGGER.debug('Make GeoJSON from Shapefile...')
        df = pd.read_csv(out_stationSamplesTableCSVFilePath)
        df = df.drop_duplicates(subset=['Longitude..degrees_east.', 'Latitude..degrees_north.'])
        geometry = [shapely.geometry.Point(xy) for xy in zip(df['Longitude..degrees_east.'], df['Latitude..degrees_north.'])]
        gdf = gpd.GeoDataFrame(df, geometry=geometry)
        gdf = gdf[['UnitID', 'geometry']]

        # Write spatial units to geojson file:
        geojson_path = out_stationSamplesTableCSVFilePath.replace("csv", "json")
        gdf.to_file(geojson_path, driver='GeoJSON')

        # Return GeoJSON directly: It tends to be very long, so bad idea!
        #with open(geojson_path, 'r') as myfile:
        #    geojson_directly = json.load(myfile)

        # Return link to GeoJSON file:
        geojson_url = out_stationSamplesTableCSV_url.replace("csv", "json")

        # Return a link to the viewer:
        filename = 'StationSamples'
        viewer_url = self.download_url.replace('/download', '')
        viewer_url += f'/viewer.html?filebase={filename}&job_id={self.job_id}&process_id={self.process_id}'

        # Return link to gridded units:
        if unitsGriddedFileUrl == "default":
            if self.download_dir in in_unitsGriddedFilePath:
                LOGGER.debug('Gridded units: Located in downloadable directory...')
                gridded_url = in_unitsGriddedFilePath.replace(self.download_dir, self.download_url)
                if in_unitsGriddedFilePath.endswith('shp'):
                    LOGGER.debug('Gridded units: Is shapefile. Check if zipped...')
                    if os.path.isfile(in_unitsGriddedFilePath.replace('shp', 'zip')):
                        LOGGER.debug('Gridded units: Is shapefile. Yes, is zipped...')
                        gridded_url = gridded_url.replace('shp', 'zip')
                    else:
                        LOGGER.debug('Gridded units: Is shapefile. Zipping...')
                        zip_path = zip_a_shapefile(in_unitsGriddedFilePath)
                        gridded_url = gridded_url.replace('shp', 'zip')
                LOGGER.debug(f'Gridded units: Will access default file here: {gridded_url}...')
            else:
                LOGGER.debug('Gridded units: Not located in downloadable directory, will not provide url...')
                gridded_url = None
                # TODO (maybe one day): Currently not needed, as the files sit in a directory which is below
                # /var/www/nginx. If we ever need this, we'd need to zip and copy the shapefile to download dir.
                # That's slow, so possibly, we could check if it already exist and compare md5sums or so.

        else:
            LOGGER.debug('Gridded units: Returning URL that the user provided...')
            gridded_url = unitsGriddedFileUrl


        ######################
        ### Return results ###
        ######################

        # Return link to output csv files and return it wrapped in JSON:
        # Note: We do not provide a link to the grid units, they are always the same, and they
        # are in the directory for static-inputs, not in the download dir...
        # TODO: Still provide it?
        outputs = {
            "outputs": {
                "station_samples": {
                    "title": PROCESS_METADATA['outputs']['station_samples']['title'],
                    "description": PROCESS_METADATA['outputs']['station_samples']['description'],
                    "href": out_stationSamplesTableCSV_url,
                    "href_geojson": geojson_url,
                    "href_viewer": viewer_url
                },
                "bottle_samples": {
                    "title": PROCESS_METADATA['outputs']['bottle_samples']['title'],
                    "description": PROCESS_METADATA['outputs']['bottle_samples']['description'],
                    "href": out_stationSamplesBOT_url
                },
                "pump_samples": {
                    "title": PROCESS_METADATA['outputs']['pump_samples']['title'],
                    "description": PROCESS_METADATA['outputs']['pump_samples']['description'],
                    "href": out_stationSamplesPMP_url
                },
                "ctd_samples": {
                    "title": PROCESS_METADATA['outputs']['ctd_samples']['title'],
                    "description": PROCESS_METADATA['outputs']['ctd_samples']['description'],
                    "href": out_stationSamplesCTD_url
                },
                "units_gridded": {
                    "title": PROCESS_METADATA['outputs']['units_gridded']['title'],
                    "description": PROCESS_METADATA['outputs']['units_gridded']['description'],
                    "href": gridded_url
                }
            }
        }

        return 'application/json', outputs
