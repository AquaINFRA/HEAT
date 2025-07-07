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
curl -X POST 'http://localhost:5000/processes/heat4advanced/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "annual_indicators": "https://testserver.com/download/AnnualIndicators.csv",
        "table_indicators": "https://example.fi/download/table_indicators.csv",
        "table_indicator_units": "https://example.fi/download/table_indicator_units.csv"
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
            self.image_name = "heat:20250701"


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

        #raise NotImplementedError("This is not implemented yet.")
        # This might already work!

        ##############
        ### Inputs ###
        ##############

        # Retrieve user inputs:
        annual_indicators_csv_url = data.get('annual_indicators')
        table_indicators_url = data.get('table_indicators')
        table_indicator_units_url = data.get('table_indicator_units')

        # Check user inputs:
        if annual_indicators_csv_url is None:
            raise ProcessorExecuteError('Missing parameter "annual_indicators". Please provide a URL to your input data.')
        if table_indicators_url is None:
            raise ProcessorExecuteError('Missing parameter "table_indicators". Please provide a URL to your input table.')
        if table_indicator_units_url is None:
            raise ProcessorExecuteError('Missing parameter "table_indicator_units". Please provide a URL to your input table.')


        ##################
        ### Input data ###
        ##################

        # Download config tables (instead of retrieving from static data)...
        in_configIndicatorsFilePath = download_file(table_indicators_url, self.download_dir+'/out/', 'indicators-%s.csv' % self.job_id)
        in_configIndicatorUnitsFilePath = download_file(table_indicator_units_url, self.download_dir+'/out/', 'indicatorunits-%s.csv' % self.job_id)

        # Download station samples from user... (same as in HOLAS)
        filename = 'annual_indicators-%s.csv' % self.job_id
        in_AnnualIndicatorPath = download_file(annual_indicators_csv_url, self.download_dir+'/out/', filename)
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

