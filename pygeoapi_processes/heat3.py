import logging
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError
LOGGER = logging.getLogger(__name__)

import json
import requests
import os
import traceback
from pygeoapi.process.HEAT.pygeoapi_processes.docker_utils import run_docker_container


'''
curl -X POST 'https://localhost:5000/processes/heat3/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "assessment_period": "holas-2",
        "samples": "https://example.com/download/StationSamplesCombined.csv",
        "combined_Chlorophylla_IsWeighted": true
    }
}'

'''


# Process metadata and description
# Has to be in a JSON file of the same name, in the same dir! 
script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))



class HEAT3Processor(BaseProcessor):

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
        return f'<HEAT3Processor> {self.name}'


    def execute(self, data):
        LOGGER.info('Starting process HEAT 3!')
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
        samples_url = data.get('samples')
        combined_Chlorophylla_IsWeighted = data.get('combined_Chlorophylla_IsWeighted')
        LOGGER.debug('Chlorophyll flag: %s %s' % (combined_Chlorophylla_IsWeighted, type(combined_Chlorophylla_IsWeighted)))

        # Check user inputs:
        if assessment_period is None:
            raise ProcessorExecuteError('Missing parameter "assessment_period". Please provide a string.')
        if samples_url is None:
            raise ProcessorExecuteError('Missing parameter "samples". Please provide a URL to your input data.')
        if combined_Chlorophylla_IsWeighted is None:
            raise ProcessorExecuteError('Missing parameter "combined_Chlorophylla_IsWeighted". Please provide an boolean.')

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
        in_unitsCleanedFilePath = get_path_cleaned_units(assessment_period, path_input_data)

        # Define paths to static input paths depending on assessment_period
        in_configIndicatorsFilePath = get_config_file_path('Indicators', assessment_period, path_input_data)
        in_configIndicatorUnitsFilePath = get_config_file_path('IndicatorUnits', assessment_period, path_input_data)
        in_configIndicatorUnitResultsFilePath = get_config_file_path('IndicatorUnitResults', assessment_period, path_input_data)

        filename_samples = 'samples-%s.csv' % self.job_id
        in_relevantStationSamplesPath = download_samples(samples_url, self.download_dir+'/out/', filename_samples)
        # TODO: /out/ is for the outputs, the inputs should be downloaded inside the container to /in, which is
        # not mounted. So temporarily, I will download this input to /out, just so it gets mounted...


        ###############
        ### Outputs ###
        ###############

        # Where to store output data
        out_annual_indicators_filepath = self.download_dir+'/out/AnnualIndicators-%s.csv' % self.job_id

        # Where to access output data
        out_annual_indicators_url      = self.download_url+'/out/AnnualIndicators-%s.csv' % self.job_id


        ###########
        ### Run ###
        ###########

        # Actually call R script:
        script_name = 'run_heat3_csv.R'
        r_args = [
            in_relevantStationSamplesPath,
            in_unitsCleanedFilePath,
            in_configIndicatorsFilePath,
            in_configIndicatorUnitsFilePath,
            in_configIndicatorUnitResultsFilePath,
            combined_Chlorophylla_IsWeighted,
            out_annual_indicators_filepath
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
        # Result:
        # * AnnualIndicators.csv

        # Return R error message if exit code not 0:
        if not returncode == 0:
            raise ProcessorExecuteError(user_msg = user_err_msg)


        ######################
        ### Return results ###
        ######################

        # Return output csv file as string directly in HTTP payload:
        outputs = {
            "outputs": {
                "annual_indicators": {
                    "title": PROCESS_METADATA['outputs']['annual_indicators']['title'],
                    "description": PROCESS_METADATA['outputs']['annual_indicators']['description'],
                    "href": out_annual_indicators_url
                }
            }
        }

        return 'application/json', outputs


def get_path_cleaned_units(assessment_period, path_input_data):
    # TODO: Merge with same function for gridded...

    if assessment_period == "1877-9999":
        return path_input_data+"/adapted_inputs/1877-9999/units_cleaned.shp"
    elif assessment_period == "2011-2016":
        return path_input_data+"/adapted_inputs/2011-2016/units_cleaned.shp"
    elif assessment_period == "2016-2021":
        return path_input_data+"/adapted_inputs/2016-2021/units_cleaned.shp"


def get_config_file_path(which_config, assessment_period, path_input_data):
    # TODO: Move to utils, used in heat1, heat3, heat4, heat5...

    if not which_config in ['Indicators', 'IndicatorUnits', 'IndicatorUnitResults', 'UnitGridSize']:
        err_msg = 'Trying to retrieve unknown config file: %s' % which_config
        LOGGER.error(err_msg)
        raise ValueError(err_msg)

    if assessment_period == "1877-9999":
        return path_input_data+"/adapted_inputs/1877-9999/Configuration1877-9999_%s.csv" % which_config
    elif assessment_period == "2011-2016":
        return path_input_data+"/adapted_inputs/2011-2016/Configuration2011-2016_%s.csv" % which_config
    elif assessment_period == "2016-2021":
        return path_input_data+"/adapted_inputs/2016-2021/Configuration2016-2021_%s.csv" % which_config


def download_samples(data_url, download_dir, filename):
    # TODO: Make better download function! SAFER!
    if not "igb-berlin.de" in data_url:
        # This is super stupid, as it can easily be faked... TODO!!!!
        raise NotImplementedError("Currently not allowed")

    #raise NotImplementedError("Need to implement download inside container...")
    # TODO: If the download URL is from our domain, it might be the result of a previous tool, and we
    # could re-use instead of download...
    data_path = download_dir+'/'+filename
    LOGGER.debug('Downloading samples: %s from %s' % (filename, data_url))
    resp = requests.get(data_url)
    if not resp.status_code == 200:
        raise ProcessorExecuteError('Could not download input file (HTTP status %s): %s' % (resp.status_code, data_url))

    with open(data_path, 'wb') as myfile:
        for chunk in resp.iter_content(chunk_size=1024):
            if chunk:
                myfile.write(chunk)

    LOGGER.debug('Downloaded to: %s' % data_path)
    return data_path
