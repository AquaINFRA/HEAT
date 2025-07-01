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
from pygeoapi.process.HEAT.pygeoapi_processes.docker_utils import run_docker_container
from pygeoapi.process.HEAT.pygeoapi_processes.heat_utils import download_zipped_data
from pygeoapi.process.HEAT.pygeoapi_processes.heat2 import get_path_bottle_input_data
from pygeoapi.process.HEAT.pygeoapi_processes.heat2 import get_path_ctd_input_data
from pygeoapi.process.HEAT.pygeoapi_processes.heat2 import get_path_pmp_input_data



'''
curl -X POST 'https://localhost:5000/processes/heat2/execution' \
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

        # Set config:
        config_file_path = os.environ.get('AQUAINFRA_CONFIG_FILE', "./config.json")
        with open(config_file_path, 'r') as config_file:
            config = json.load(config_file)
            self.download_dir = config["download_dir"].rstrip('/')
            self.download_url = config["download_url"].rstrip('/')
            self.inputs_read_only = config["helcom_heat"]["input_dir"].rstrip('/')
            self.docker_executable = config["docker_executable"]
            self.image_name = "heat:20250701"


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

        #######################
        ### NOT IMPLEMENTED ###
        #######################

        #raise NotImplementedError("This is not implemented yet.")
        # This could actually work!

        ##################
        ### Input data ###
        ##################

        # Directory where static input data can be found. It will be mounted read-only to the container:
        path_input_data = self.inputs_read_only

        ## Download input shape:
        in_unitsGriddedFileName = units_gridded_url.split('/')[-1]
        #in_unitsGriddedFilePath = download_file(units_gridded_url, self.download_dir+'/out/', in_unitsGriddedFileName)
        ## TODO: Zipped shapes, be careful!!
        in_unitsGriddedFilePath = download_zipped_data(units_gridded_url, self.download_dir+'/out/', in_unitsGriddedFileName, suffix="shp")

        # Download input data, or provide path to default, or None
        # (Currently, downloading+unzipping is not allowed, because it is unsafe)
        # TODO: We can use these methods if we are ok with a default, and provide a default assessment period!
        in_stationSamplesBOTFilePath = get_path_bottle_input_data("1877-9999", bot_url, path_input_data, self.download_dir)
        in_stationSamplesCTDFilePath = get_path_ctd_input_data("1877-9999", ctd_url, path_input_data, self.download_dir)
        in_stationSamplesPMPFilePath = get_path_pmp_input_data("1877-9999", pmp_url, path_input_data, self.download_dir)


        ###############
        ### Outputs ###
        ###############

        # Where to store output data
        out_stationSamplesTableCSVFilePath = self.download_dir+'/out/StationSamples-%s.csv' % self.job_id
        out_stationSamplesBOTFilePath      = self.download_dir+"/out/StationSamplesBOT-%s.csv" % self.job_id
        out_stationSamplesCTDFilePath      = self.download_dir+"/out/StationSamplesCTD-%s.csv" % self.job_id
        out_stationSamplesPMPFilePath      = self.download_dir+"/out/StationSamplesPMP-%s.csv" % self.job_id

        # Where to access output data
        out_stationSamplesTableCSV_url = self.download_url+'/out/StationSamples-%s.csv' % self.job_id
        out_stationSamplesBOT_url      = self.download_url+"/out/StationSamplesBOT-%s.csv" % self.job_id
        out_stationSamplesCTD_url      = self.download_url+"/out/StationSamplesCTD-%s.csv" % self.job_id
        out_stationSamplesPMP_url      = self.download_url+"/out/StationSamplesPMP-%s.csv" % self.job_id


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
        returncode, stdout, stderr, user_err_msg = run_docker_container(
            self.docker_executable,
            self.image_name,
            script_name,
            self.job_id,
            self.download_dir,
            self.inputs_read_only,
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

        ## Make GeoJSON: TODO WIP
        geojson_path = out_stationSamplesTableCSVFilePath.replace("csv", "json")
        df = pd.read_csv(out_stationSamplesTableCSVFilePath)
        df = df.drop_duplicates(subset=['Longitude..degrees_east.', 'Latitude..degrees_north.'])
        geometry = [shapely.geometry.Point(xy) for xy in zip(df['Longitude..degrees_east.'], df['Latitude..degrees_north.'])]
        gdf = gpd.GeoDataFrame(df, geometry=geometry)
        gdf = gdf[['UnitID', 'geometry']]
        gdf.to_file(geojson_path, driver='GeoJSON')
        with open(geojson_path, 'r') as myfile:
            geojson_samples = json.load(myfile)


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
                    "as_geojson": geojson_samples
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

