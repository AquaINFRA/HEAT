import logging
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError
LOGGER = logging.getLogger(__name__)

import json
import requests
import os
import traceback
from pygeoapi.process.HEAT.pygeoapi_processes.docker_utils import run_docker_container
from pygeoapi.process.HEAT.pygeoapi_processes.heat_utils import download_zipped_data



'''
curl -X POST 'https://localhost:5000/processes/heat2/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "assessment_period": "holas-2",
        "bottle_data": "default",
        "pump_data": "default",
        "ctd_data": "default"
    }
}'

NOTCOMMIT:
curl -X POST 'https://aquainfra.ogc.igb-berlin.de/pygeoapi/processes/heat2/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "assessment_period": "holas-2",
        "bottle_data": "default",
        "pump_data": "default",
        "ctd_data": "default"
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
            self.image_name = "heat:20250525"


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
        assessment_period = data.get('assessment_period').lower()
        bot_url = data.get('bottle_data', None)
        ctd_url = data.get('ctd_data', None)
        pmp_url = data.get('pump_data', None)

        # Check user inputs:
        if assessment_period is None:
            raise ProcessorExecuteError('Missing parameter "assessment_period". Please provide a string.')

        # Check validity of argument:
        valid_assessment_periods = ["holas-2", "holas-3", "other"]
        if not assessment_period in valid_assessment_periods:
            raise ValueError('assessment_period is "%s", must be one of: %s' % (assessment_period, valid_assessment_periods))

        # Assign years to selected assessment period:
        if assessment_period == 'holas-2':
            assessment_period = '2011-2016'
        elif assessment_period == 'holas-3':
            assessment_period = '2016-2021'
        elif assessment_period == 'other':
            assessment_period = '1877-9999'


        ##################
        ### Input data ###
        ##################

        # Directory where static input data can be found. It will be mounted read-only to the container:
        path_input_data = self.inputs_read_only

        ## Use pre-computed input shapes, as they are always the same anyway:
        in_unitsGriddedFilePath = get_path_gridded_units(assessment_period, path_input_data)

        # Download input data, or provide path to default, or None
        # (Currently, downloading+unzipping is not allowed, because it is unsafe)
        in_stationSamplesBOTFilePath = get_path_bottle_input_data(assessment_period, bot_url, path_input_data, self.download_dir)
        in_stationSamplesCTDFilePath = get_path_ctd_input_data(assessment_period, ctd_url, path_input_data, self.download_dir)
        in_stationSamplesPMPFilePath = get_path_pmp_input_data(assessment_period, pmp_url, path_input_data, self.download_dir)


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


        ######################
        ### Return results ###
        ######################

        # Return link to output csv files and return it wrapped in JSON:
        # Note: We do not provide a link to the grid units, they are always the same, and they
        # are in the directory for static-inputs, not in the download dir...
        # TODO: Still provide it?
        outputs = {
            "outputs": {
                "samples": {
                    "title": PROCESS_METADATA['outputs']['samples']['title'],
                    "description": PROCESS_METADATA['outputs']['samples']['description'],
                    "href": out_stationSamplesTableCSV_url
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
                    "href": None
                }
            }
        }

        return 'application/json', outputs

def get_path_gridded_units(assessment_period, path_input_data):

    unitsGriddedFilePath = None
    if assessment_period == "1877-9999":
        unitsGriddedFilePath = path_input_data+"/adapted_inputs/1877-9999/units_gridded.shp"
    elif assessment_period == "2011-2016":
        unitsGriddedFilePath = path_input_data+"/adapted_inputs/2011-2016/units_gridded.shp"
    elif assessment_period == "2016-2021":
        unitsGriddedFilePath = path_input_data+"/adapted_inputs/2016-2021/units_gridded.shp"
    return unitsGriddedFilePath


def get_path_default_bottle_data(assessment_period, path_input_data):

    bot_path = None
    if assessment_period == "1877-9999":
        bot_path = path_input_data+"/1877-9999/StationSamples1877-9999BOT_2022-12-09.txt.gz"
    elif assessment_period == "2011-2016":
        bot_path = path_input_data+"/2011-2016/StationSamples2011-2016BOT_2022-12-09.txt.gz"
    elif assessment_period == "2016-2021":
        bot_path = path_input_data+"/2016-2021/StationSamples2016-2021BOT_2022-12-09.txt.gz"
    return bot_path


def get_path_default_pmp_data(assessment_period, path_input_data):

    pmp_path = None
    if assessment_period == "1877-9999":
        pmp_path = path_input_data+"/1877-9999/StationSamples1877-9999PMP_2022-12-09.txt.gz"
    elif assessment_period == "2011-2016":
        pmp_path = path_input_data+"/2011-2016/StationSamples2011-2016PMP_2022-12-09.txt.gz"
    elif assessment_period == "2016-2021":
        pmp_path = path_input_data+"/2016-2021/StationSamples2016-2021PMP_2022-12-09.txt.gz"
    return pmp_path


def get_path_default_ctd_data(assessment_period, path_input_data):

    ctd_path = None
    if assessment_period == "1877-9999":
        ctd_path = path_input_data+"/1877-9999/StationSamples1877-9999CTD_2022-12-09.txt.gz"
    elif assessment_period == "2011-2016":
        ctd_path = path_input_data+"/2011-2016/StationSamples2011-2016CTD_2022-12-09.txt.gz"
    elif assessment_period == "2016-2021":
        ctd_path = path_input_data+"/2016-2021/StationSamples2016-2021CTD_2022-12-09.txt.gz"
    return ctd_path


def get_path_bottle_input_data(assessment_period, bot_url, path_input_data, download_dir):

    if bot_url is None:
        # If the user passed nothing or "null", no bottle data is used!
        # TODO: Dont return/store results for BOT, if no bottle inputs are given!
        return None

    elif bot_url is not None and bot_url.lower() == 'default':
        LOGGER.info('Client did not provide bottle data, using pre-stored ones...')
        bot_path = get_path_default_bottle_data(assessment_period, path_input_data)
        return bot_path

    elif bot_url is not None and bot_url.startswith('http'):
        LOGGER.info('Client requested bottle data: %s' % bot_url)
        #raise NotImplementedError("Currently, only default bottle data can be used!")
        # TODO: Ideally, the download should not happen here (in the process python file), but
        # inside the docker container.
        filename = bot_url.split('/')[-1]
        bot_path = download_zipped_data(bot_url, download_dir+'/out/', filename, suffix="csv")
        # TODO: /out/ is for the outputs, the inputs should be downloaded inside the container to /in, which is
        # not mounted. So temporarily, I will download this input to /out, just so it gets mounted...
        return bot_path

    else:
        err_msg = 'Could not understand bottle data: %s' % bot_url
        LOGGER.error(err_msg)
        raise ProcessorExecuteError(err_msg)


def get_path_pmp_input_data(assessment_period, pmp_url, path_input_data, download_dir):

    if pmp_url is None:
        # If the user passed nothing or "null", no pump data is used!
        # TODO: Dont return/store results for PMP, if no PMP inputs are given!
        return None

    elif pmp_url.lower() == 'default':
        LOGGER.info('Client did not provide pump data, using pre-stored ones...')
        pmp_path = get_path_default_pmp_data(assessment_period, path_input_data)
        return pmp_path

    elif pmp_url is not None and pmp_url.startswith('http'):
        LOGGER.info('Client requested pump data: %s' % pmp_url)
        raise NotImplementedError("Currently, only default pump data can be used!")
        # TODO: Ideally, the download should not happen here (in the process python file), but
        # inside the docker container.
        #pmp_path = download_zipped_data(pmp_url, download_dir, 'PMP')
        #return pmp_path

    else:
        err_msg = 'Could not understand pump data: %s' % pmp_url
        LOGGER.error(err_msg)
        raise ProcessorExecuteError(err_msg)


def get_path_ctd_input_data(assessment_period, ctd_url, path_input_data, download_dir):

    if ctd_url is None:
        # If the user passed nothing or "null", no pump data is used!
        # TODO: Dont return/store results for CTD, if no CTD inputs are given!
        return None

    elif ctd_url.lower() == 'default':
        LOGGER.info('Client did not provide ctd data, using pre-stored ones...')
        ctd_path = get_path_default_pmp_data(assessment_period, path_input_data)
        return ctd_path

    elif ctd_url is not None and ctd_url.startswith('http'):
        LOGGER.info('Client requested ctd data: %s' % ctd_url)
        raise NotImplementedError("Currently, only default ctd data can be used!")
        # TODO: Ideally, the download should not happen here (in the process python file), but
        # inside the docker container.
        #ctd_path = download_zipped_data(ctd_url, download_dir, 'CTD')
        #return ctd_path

    else:
        err_msg = 'Could not understand ctd data: %s' % ctd_url
        LOGGER.error(err_msg)
        raise ProcessorExecuteError(err_msg)

