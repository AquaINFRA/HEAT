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
curl -X POST 'http://localhost:5000/processes/heat3/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "assessment_period": "holas-2",
        "station_samples": "https://example.com/download/StationSamplesCombined.csv",
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
        samples_url = data.get('station_samples')
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

        # Where to store input data (will be mounted read-write into container):
        input_dir = f'{self.download_dir}/in/{self.process_id}_job_{self.job_id}'
        os.makedirs(input_dir, exist_ok=True)

        # Directory where static input data can be found (will be mounted readonly into container):
        readonly_dir = self.inputs_read_only

        ## Use pre-computed input shapes, as they are always the same anyway:
        in_unitsCleanedFilePath = get_path_cleaned_units(assessment_period, readonly_dir)

        # Define paths to static input paths depending on assessment_period
        in_configIndicatorsFilePath = get_config_file_path('Indicators', assessment_period, readonly_dir)
        in_configIndicatorUnitsFilePath = get_config_file_path('IndicatorUnits', assessment_period, readonly_dir)
        in_configIndicatorUnitResultsFilePath = get_config_file_path('IndicatorUnitResults', assessment_period, readonly_dir)

        # Download station samples from user...
        filename_samples = 'samples-%s.csv' % self.job_id
        in_relevantStationSamplesPath = download_file(samples_url, input_dir, filename_samples)
        # TODO: Ihe inputs should be downloaded inside the container, which is not implemented
        # yet, so temporarily, I will download this in this python process file.


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
        out_annual_indicators_filepath = f'{output_dir}/AnnualIndicators-{self.job_id}.csv'

        # Where to access output data
        out_annual_indicators_url      = out_annual_indicators_filepath.replace(self.download_dir, self.download_url)


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
        returncode, stdout, stderr, user_err_msg = run_docker_container2(
            self.docker_executable,
            self.image_name,
            script_name,
            input_dir,
            output_dir,
            readonly_dir,
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

        # Return link to output csv files and return it wrapped in JSON:
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


def get_path_cleaned_units(assessment_period, readonly_dir):
    # TODO: Merge with same function for gridded...

    if assessment_period == "1877-9999":
        return readonly_dir+"/adapted_inputs/1877-9999/units_cleaned.shp"
    elif assessment_period == "2011-2016":
        return readonly_dir+"/adapted_inputs/2011-2016/units_cleaned.shp"
    elif assessment_period == "2016-2021":
        return readonly_dir+"/adapted_inputs/2016-2021/units_cleaned.shp"


