import logging
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError
LOGGER = logging.getLogger(__name__)

import json
import os
import traceback
from pygeoapi.process.HEAT.pygeoapi_processes.docker_utils import run_docker_container
from pygeoapi.process.HEAT.pygeoapi_processes.heat_utils import get_config_file_path
from pygeoapi.process.HEAT.pygeoapi_processes.heat_utils import download_file


'''
curl -X POST 'http://localhost:5000/processes/heat4/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "assessment_period": "holas-2",
        "annual_indicators": "https://example.com/download/AnnualIndicators.csv"
    }
}'

'''


# Process metadata and description
# Has to be in a JSON file of the same name, in the same dir! 
script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))



class HEAT4Processor(BaseProcessor):

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
            self.image_name = "heat:20250708"


    def set_job_id(self, job_id: str):
        self.job_id = job_id

    def __repr__(self):
        return f'<HEAT4Processor> {self.name}'


    def execute(self, data):
        LOGGER.info('Starting process HEAT 4!')
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
        annual_indicators_csv_url = data.get('annual_indicators')

        # Check user inputs:
        if assessment_period is None:
            raise ProcessorExecuteError('Missing parameter "assessment_period". Please provide a string.')
        if annual_indicators_csv_url is None:
            raise ProcessorExecuteError('Missing parameter "annual_indicators_csv_url". Please provide a URL to your input data.')

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

        # Define paths to static input paths depending on assessment_period
        in_configIndicatorsFilePath = get_config_file_path('Indicators', assessment_period, path_input_data)
        in_configIndicatorUnitsFilePath = get_config_file_path('IndicatorUnits', assessment_period, path_input_data)

        filename_annual_indicators = 'annual_indicators-%s.csv' % self.job_id
        in_AnnualIndicatorPath = download_file(annual_indicators_csv_url, self.download_dir+'/out/', filename_annual_indicators)
        # TODO: /out/ is for the outputs, the inputs should be downloaded inside the container to /in, which is
        # not mounted. So temporarily, I will download this input to /out, just so it gets mounted...


        ###############
        ### Outputs ###
        ###############

        # Where to store output data
        out_assessment_indicators_filepath = self.download_dir+'/out/AssessmentIndicators-%s.csv' % self.job_id

        # Where to access output data
        out_assessment_indicators_url      = self.download_url+'/out/AssessmentIndicators-%s.csv' % self.job_id


        ###########
        ### Run ###
        ###########

        # Actually call R script:
        script_name = 'run_heat4_csv.R'
        r_args = [
            in_AnnualIndicatorPath,
            in_configIndicatorsFilePath,
            in_configIndicatorUnitsFilePath,
            out_assessment_indicators_filepath,
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
        # There are no results, except for one CSV of the Assessment Indicator:
        # * AssessmentIndicators.csv

        # Return R error message if exit code not 0:
        if not returncode == 0:
            raise ProcessorExecuteError(user_msg = user_err_msg)


        ######################
        ### Return results ###
        ######################

        # Return link to output csv files and return it wrapped in JSON:
        outputs = {
            "outputs": {
                "assessment_indicators": {
                    "title": PROCESS_METADATA['outputs']['assessment_indicators']['title'],
                    "description": PROCESS_METADATA['outputs']['assessment_indicators']['description'],
                    "href": out_assessment_indicators_url
                }
            }
        }
        return 'application/json', outputs

