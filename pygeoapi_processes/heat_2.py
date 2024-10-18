import logging
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError
LOGGER = logging.getLogger(__name__)

import subprocess
import json
import requests
import zipfile
import os
import sys
import traceback
from pygeoapi.process.HEAT.pygeoapi_processes.utils import call_r_script


'''
curl -X POST "http://localhost:5000/processes/heat_2/execution" -H "Content-Type: application/json" -d "{\"inputs\":{\"assessment_period\": \"2016-2021\"}}"

curl -X POST "http://localhost:5000/processes/heat_2/execution" -H "Content-Type: application/json" -d "{\"inputs\":{\"assessment_period\": \"2016-2021\", \"bottle_data\": \"https://testserver.com/download/f2369468-30f8-4add-8a5d-25cf768f5096.csv\"}}"

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
        config_file_path = os.environ.get('HELCOM_CONFIG_FILE', "./config.json")
        with open(config_file_path, 'r') as config_file:
            self.config = json.load(config_file)['helcom_heat']

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

        # User input:
        #assessment_period = data.get('assessment_period')
        bot_url = data.get('bottle_data', None)
        ctd_url = data.get('ctd_data', None)
        pmp_url = data.get('pump_data', None)
        gridded_units_url = data.get('spatial_units_gridded', None)

        raise ProcessorExecuteError('NOT IMPLEMENTED: HEAT 2 Advanced mode is not implemented yet. Please use HOLAS mode as of now. Thanks!')


        # Check user inputs:
        #if assessment_period is None:
        #    raise ProcessorExecuteError('Missing parameter "assessment_period". Please provide a string.')
        #
        # Check validity of argument:
        #validAssessmentPeriods = ["1877-9999", "2011-2016", "2016-2021"]
        #if not assessment_period in validAssessmentPeriods:
        #    raise ValueError('assessment_period is "%s", must be one of: %s' % (assessment_period, validAssessmentPeriods))

        # Input data! Where to look for input data
        download_dir = self.config["download_dir"].rstrip('/')
        path_input_data = self.config['input_path'].rstrip('/')

        #########################
        ### Bottle input data ###
        #########################
        bot_path = None
        if bot_url is not None and bot_url.startswith('http'):
            LOGGER.info('Client requested bottle data: %s' % bot_url)
            bot_name = bot_url.split('/')[-1]
            bot_path = download_dir+'/heat_inputs/'+bot_name
            if os.path.exists(bot_path):
                LOGGER.debug('Found: %s' % bot_path)
            else:

                ## Downloading bottle data:
                LOGGER.debug('Downloading bottle data: %s from %s' % (bot_name, bot_url))
                resp = requests.get(bot_url)
                with open(bot_path, 'wb') as myfile:
                    myfile.write(resp.content)
                    LOGGER.debug('Downloaded to: %s' % bot_path)

        ## Unzipping downloaded data, unless already unzipped:
        if zipfile.is_zipfile(bot_path):
            bot_path_unzipped = download_dir+'/heat_inputs/unzipped_'+bot_name
            if os.path.exists(bot_path_unzipped):
                LOGGER.debug('Found: %s' % bot_path_unzipped)
            else:
                LOGGER.debug('Unzipping to %s' % bot_path_unzipped)
                with zipfile.ZipFile(bot_path, 'r') as zip_ref:
                    zip_ref.extractall(bot_path_unzipped)

            bot_path = None
            for item in os.listdir(bot_path_unzipped):
                if item.endswith('.csv'):
                    bot_path = bot_path_unzipped.rstrip('/')+'/'+item

            LOGGER.debug('Will use this file from unzipped dir: %s' % bot_path)


        elif bot_url is None:
            LOGGER.info('Client did not provide bottle data, using pre-stored ones...')
            if assessment_period == "1877-9999":
                bot_path = path_input_data+os.sep+"1877-9999/StationSamples1877-9999BOT_2022-12-09.txt.gz"
            elif assessment_period == "2011-2016":
                bot_path = path_input_data+os.sep+"2011-2016/StationSamples2011-2016BOT_2022-12-09.txt.gz"
            elif assessment_period == "2016-2021":
                bot_path = path_input_data+os.sep+"2016-2021/StationSamples2016-2021BOT_2022-12-09.txt.gz"

        else:
            LOGGER.info('Bottle data passed directly: %s...' % bot_url[:300])
            bot_path = download_dir +'/bottle_client_%s.csv' % self.job_id
            with open(bot_path, 'w') as myfile:
                myfile.write(bot_url)
            LOGGER.info('Written to file: %s' % bot_path)

        #######################
        ### Pump input data ###
        #######################
        pmp_path = None
        if pmp_url is not None:
            LOGGER.info('Client requested pump data: %s' % pmp_url)
            # TODO: Check if the url is OURS!!
            pmp_name = pmp_url.split('/')[-1]
            pmp_path = download_dir+'/'+pmp_name
            if os.path.exists(pmp_path):
                LOGGER.debug('Found: %s' % pmp_path)
            else:
                LOGGER.debug('Downloading pump data: %s from %s' % (pmp_name, pmp_url))
                resp = requests.get(pmp_url)
                with open(pmp_path, 'w') as myfile:
                    myfile.write(resp.content)
                    LOGGER.debug('Downloaded: %s' % pmp_path)

        if pmp_url is None: 
            LOGGER.info('Client did not provide pump data, using pre-stored ones...')
            if assessment_period == "1877-9999":
                pmp_path = path_input_data+os.sep+"1877-9999/StationSamples1877-9999PMP_2022-12-09.txt.gz"
            elif assessment_period == "2011-2016":
                pmp_path = path_input_data+os.sep+"2011-2016/StationSamples2011-2016PMP_2022-12-09.txt.gz"
            elif assessment_period == "2016-2021":
                pmp_path = path_input_data+os.sep+"2016-2021/StationSamples2016-2021PMP_2022-12-09.txt.gz"


        #######################
        ### ctd input data ###
        #######################
        ctd_path = None
        if ctd_url is not None:
            LOGGER.info('Client requested pump data: %s' % ctd_url)
            # TODO: Check if the url is OURS!!
            ctd_name = ctd_url.split('/')[-1]
            ctd_path = download_dir+'/'+ctd_name
            if os.path.exists(ctd_path):
                LOGGER.debug('Found: %s' % ctd_path)
            else:
                LOGGER.debug('Downloading pump data: %s from %s' % (ctd_name, ctd_url))
                resp = requests.get(ctd_url)
                with open(ctd_path, 'w') as myfile:
                    myfile.write(resp.content)
                    LOGGER.debug('Downloaded: %s' % ctd_path)

        if ctd_url is None:
            LOGGER.info('Client did not provide ctd data, using pre-stored ones...')
            if assessment_period == "1877-9999":
                ctd_path = path_input_data+os.sep+"1877-9999/StationSamples1877-9999CTD_2022-12-09.txt.gz"
            elif assessment_period == "2011-2016":
                ctd_path = path_input_data+os.sep+"2011-2016/StationSamples2011-2016CTD_2022-12-09.txt.gz"
            elif assessment_period == "2016-2021":
                ctd_path = path_input_data+os.sep+"2016-2021/StationSamples2016-2021CTD_2022-12-09.txt.gz"


        #############################
        ### grid units input data ###
        #############################
        in_gridded_units_filepath = None
        if gridded_units_url is not None:
            LOGGER.info('Client requested gridded units data: %s' % gridded_units_url)
            # TODO: Check if the url is OURS!!
            in_gridded_units_filename = gridded_units_url.split('/')[-1]
            in_gridded_units_filepath = download_dir+'/'+in_gridded_units_filename
            if os.path.exists(in_gridded_units_filepath):
                LOGGER.debug('Found: %s' % in_gridded_units_filepath)
            else:
                LOGGER.debug('Downloading grid units data: %s from %s' % (in_gridded_units_filename, gridded_units_url))
                resp = requests.get(gridded_units_url)
                with open(in_gridded_units_filepath, 'w') as myfile:
                    myfile.write(resp.content)
                    LOGGER.debug('Downloaded: %s' % in_gridded_units_filepath)

        if gridded_units_url is None:
            in_gridded_units_filepath = path_input_data+"/shapefiles/%s/units_gridded.shp" % assessment_period


        # Where to store output data
        download_dir = self.config["download_dir"].rstrip('/')
        out_stationsamples_csv_filepath = download_dir+'/StationSamples-%s.csv' % self.job_id
        # Define output files
        out_stationsamples_BOT_csv_filepath = download_dir+"/StationSamplesBOT.csv"
        out_stationsamples_CTD_csv_filepath = download_dir+"/StationSamplesCTD.csv"
        out_stationsamples_PMP_csv_filepath = download_dir+"/StationSamplesPMP.csv"


        # Actually call R script:
        r_file_name = 'HEAT_subpart2_stations.R' # TODO: Some improvements to make on this R script!
        path_rscripts = self.config['r_script_dir'].rstrip('/')
        r_args = [bot_path, ctd_path, pmp_path, in_gridded_units_filepath, out_stationsamples_BOT_csv_filepath, out_stationsamples_CTD_csv_filepath, out_stationsamples_PMP_csv_filepath, out_stationsamples_csv_filepath]
        returncode, stdout, stderr, err_msg = call_r_script(LOGGER, r_file_name, path_rscripts, r_args)
        # Results:
        # * StationSamples
        # * StationSamplesBOT.csv
        # * StationSamplesCTD.csv
        # * StationSamplesPMP.csv
        
        # Return R error message if exit code not 0:
        if not returncode == 0:
            raise ProcessorExecuteError(user_msg = err_msg)



        ######################
        ### Return results ###
        ######################

        # Return output csv file as string directly in HTTP payload:
        # TODO check requested_outputs for user preference!
        # TODO returning shapefile makes no sense without zipping/without all the other files...
        
        # Or return link to output csv files and return it wrapped in JSON:
        outputs = {
            "outputs": {
                "station_samples": {
                    "title": PROCESS_METADATA['outputs']['station_samples']['title'],
                    "description": PROCESS_METADATA['outputs']['station_samples']['description'],
                    "href": self.config['download_url'].rstrip('/')+'/'+out_stationsamples_csv_filepath.split('/')[-1]
                },
                "bottle_samples": {
                    "title": PROCESS_METADATA['outputs']['bottle_samples']['title'],
                    "description": PROCESS_METADATA['outputs']['bottle_samples']['description'],
                    "href": self.config['download_url'].rstrip('/')+'/'+out_stationsamples_BOT_csv_filepath.split('/')[-1]
                },
                "pump_samples": {
                    "title": PROCESS_METADATA['outputs']['pump_samples']['title'],
                    "description": PROCESS_METADATA['outputs']['pump_samples']['description'],
                    "href": self.config['download_url'].rstrip('/')+'/'+out_stationsamples_PMP_csv_filepath.split('/')[-1]
                },
                "ctd_samples": {
                    "title": PROCESS_METADATA['outputs']['ctd_samples']['title'],
                    "description": PROCESS_METADATA['outputs']['ctd_samples']['description'],
                    "href": self.config['download_url'].rstrip('/')+'/'+out_stationsamples_CTD_csv_filepath.split('/')[-1]
                },
                "units_gridded": {
                    "title": PROCESS_METADATA['outputs']['units_gridded']['title'],
                    "description": PROCESS_METADATA['outputs']['units_gridded']['description'],
                    "href": self.config['download_url'].rstrip('/')+'/'+in_gridded_units_filepath.split('/')[-1]
                }
            }
        }

        return 'application/json', outputs


