import logging
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError
LOGGER = logging.getLogger(__name__)

import json
import os
import traceback
from pygeoapi.process.HEAT.pygeoapi_processes.docker_utils import run_docker_container2
from pygeoapi.process.HEAT.pygeoapi_processes.heat_utils import get_config_file_path
from pygeoapi.process.HEAT.pygeoapi_processes.heat_utils import download_file


'''
## Testing with dummy input data, that was output from previous dummy runs.
## Those were generated using dummy spatial units and dummy grid sizes
## (created on QGIS; they don't make any sense in the real world, except being located in the Baltic Sea)
## and with station samples derived from the bottle, pump and ctd data 
## that was provided as default by HELCOM, for HOLAS period 2 (I think)...

# Tested 2025-10-12
curl -X POST https://${PYSERVER}/processes/heat5advanced/execution \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "assessment_indicators": "https://aquainfra.ogc.igb-berlin.de/exampledata/helcom/dummy/AssessmentIndicators_20251012.csv",
        "table_indicators": "https://aquainfra.ogc.igb-berlin.de/exampledata/helcom/dummy/Configuration_dummy_Indicators.csv",
        "table_indicator_units": "https://aquainfra.ogc.igb-berlin.de/exampledata/helcom/dummy/Configuration_dummy_IndicatorUnits.csv"
    }
}'; date

'''

# Process metadata and description
# Has to be in a JSON file of the same name, in the same dir! 
script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))


class HEAT5Processor(BaseProcessor):

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
        return f'<HEAT5Processor> {self.name}'


    def execute(self, data):
        LOGGER.info('Starting process HEAT 5!')
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
        assessment_indicators_csv_url = data.get('assessment_indicators')
        table_indicators_url = data.get('table_indicators')
        table_indicator_units_url = data.get('table_indicator_units')

        # Check user inputs:
        if assessment_indicators_csv_url is None:
            raise ProcessorExecuteError('Missing parameter "assessment_indicators". Please provide a URL to your input data.')
        if table_indicators_url is None:
            raise ProcessorExecuteError('Missing parameter "table_indicators". Please provide a URL to your input table.')
        if table_indicator_units_url is None:
            raise ProcessorExecuteError('Missing parameter "table_indicator_units". Please provide a URL to your input table.')


        ##################
        ### Input data ###
        ##################

        # Where to store input data (will be mounted read-write into container):
        input_dir = f'{self.download_dir}/in/{self.process_id}/job_{self.job_id}'
        os.makedirs(input_dir, exist_ok=True)

        # Directory where static input data can be found (will be mounted readonly into container):
        readonly_dir = self.inputs_read_only

        # Download config tables (instead of retrieving from static data):
        # Download input csv provided by user: (same as in HOLAS):
        # Downloading was moved into the R script that happens inside the R script!


        ###############
        ### Outputs ###
        ###############


        # Where to store output data
        output_dir = f'{self.download_dir}/out/{self.process_id}/job_{self.job_id}'
        output_url = f'{self.download_url}/out/{self.process_id}/job_{self.job_id}'
        os.makedirs(output_dir, exist_ok=True)
        LOGGER.debug(f'All results will be stored     in: {output_dir}')
        LOGGER.debug(f'All results will be accessible in: {output_url}')

        # Where to store output data
        out_assessment_filepath = f'{output_dir}/Assessment-{self.job_id}.csv'

        # Where to access output data
        out_assessment_url = out_assessment_filepath.replace(self.download_dir, self.download_url)


        ###########
        ### Run ###
        ###########

        # Actually call R script:
        script_name = 'run_heat5_csv.R'
        r_args = [
            input_dir,
            assessment_indicators_csv_url,
            table_indicators_url,
            table_indicator_units_url,
            out_assessment_filepath
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
                "assessment": {
                    "title": PROCESS_METADATA['outputs']['assessment']['title'],
                    "description": PROCESS_METADATA['outputs']['assessment']['description'],
                    "href": out_assessment_url
                }
            }
        }
        return 'application/json', outputs

