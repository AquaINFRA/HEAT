import logging
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError
LOGGER = logging.getLogger(__name__)

import json
import requests
import os
import traceback
import pandas as pd
import geopandas as gpd
import shapely.geometry
from pygeoapi.process.HEAT.pygeoapi_processes.docker_utils import run_docker_container2
from pygeoapi.process.HEAT.pygeoapi_processes.heat_utils import download_zipped_data
from pygeoapi.process.HEAT.pygeoapi_processes.heat2 import get_path_bottle_input_data
from pygeoapi.process.HEAT.pygeoapi_processes.heat2 import get_path_ctd_input_data
from pygeoapi.process.HEAT.pygeoapi_processes.heat2 import get_path_pmp_input_data



'''
curl -X POST 'http://localhost:5000/processes/heat2advanced/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "units_gridded": "https://example.fi/download/gridded.shp.zip",
        "bottle_data": "https://example.fi/download/bot.csv",
        "pump_data": "https://example.fi/download/pmp.csv",
        "ctd_data": "https://example.fi/download/ctd.csv"
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
            self.image_name = "heat:20250708"


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
        units_gridded_url = data.get('units_gridded').lower()
        bot_url = data.get('bottle_data', None)
        ctd_url = data.get('ctd_data', None)
        pmp_url = data.get('pump_data', None)

        # Check user inputs:
        if units_gridded_url is None:
            raise ProcessorExecuteError('Missing parameter "units_gridded". Please provide URL.')
        if bot_url is None:
            raise ProcessorExecuteError('Missing parameter "bottle_data". Please provide URL.')
        if ctd_url is None:
            raise ProcessorExecuteError('Missing parameter "ctd_data". Please provide URL.')
        if pmp_url is None:
            raise ProcessorExecuteError('Missing parameter "pump_data". Please provide URL.')


        ##################
        ### Input data ###
        ##################

        # Where to store input data (will be mounted read-write into container):
        input_dir = f'{self.download_dir}/in/{self.process_id}_job_{self.job_id}'
        os.makedirs(input_dir, exist_ok=True)

        # Directory where static input data can be found (will be mounted readonly into container):
        readonly_dir = self.inputs_read_only

        ## Download input shape:
        in_unitsGriddedFileName = units_gridded_url.split('/')[-1]
        # TODO: Ihe inputs should be downloaded inside the container, which is not implemented
        # yet, so temporarily, I will download this in this python process file.
        in_unitsGriddedFilePath = download_zipped_data(units_gridded_url, input_dir, in_unitsGriddedFileName, suffix="shp")

        # Download input data, or provide path to default, or None
        # TODO: Ihe inputs should be downloaded inside the container, which is not implemented
        # yet, so temporarily, I will download this in this python process file.
        # TODO: We can use these methods if we are ok with a default, and provide a default assessment period!
        in_stationSamplesBOTFilePath = get_path_bottle_input_data("1877-9999", bot_url, readonly_dir, input_dir)
        in_stationSamplesCTDFilePath = get_path_ctd_input_data("1877-9999", ctd_url, readonly_dir, input_dir)
        in_stationSamplesPMPFilePath = get_path_pmp_input_data("1877-9999", pmp_url, readonly_dir, input_dir)


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
                }
            }
        }

        return 'application/json', outputs

