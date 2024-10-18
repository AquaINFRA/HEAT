import logging
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError
LOGGER = logging.getLogger(__name__)

import subprocess
import json
import os
import sys
import traceback
from pygeoapi.process.HEAT.pygeoapi_processes.utils import call_r_script


'''
curl -X POST "http://localhost:5001/processes/heat_5_advanced/execution" -H "Content-Type: application/json" -d "{\"inputs\":{\"table_indicators\": \"xxx\", \"table_indicator_units\": \"xxx\", \"assessment_indicators\": \"https://testserver.com/download/AssessmentIndicators-4446f118-836f-11ef-8e41-e14810fdd7f8.csv\"}}"

'''



# Process metadata and description
# Has to be in a JSON file of the same name, in the same dir! 
script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))


class HEAT5AdvancedProcessor(BaseProcessor):

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
        return f'<HEAT5AdvancedProcessor> {self.name}'

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

        # User inputs:
        #assessment_period = data.get('assessment_period')
        assessment_indicators_csv_url = data.get('assessment_indicators')

        # Check user inputs:
        if assessment_indicators_csv_url is None:
            raise ProcessorExecuteError('Missing parameter "assessment_indicators". Please provide a URL to your input data.')
        if assessment_period is None:
            raise ProcessorExecuteError('Missing parameter "assessment_period". Please provide a string.')

        # Check validity of argument:
        valid_assessment_periods = ["1877-9999", "2011-2016", "2016-2021"]
        if not assessment_period in valid_assessment_periods:
            raise ValueError('assessment_period is "%s", must be one of: %s' % (assessment_period, valid_assessment_periods))

        # Download input data or find it on local filesystem
        # TODO: Check if download url is our url!
        download_dir = self.config["download_dir"].rstrip('/')
        in_assessment_indicator_filename = assessment_indicators_csv_url.split('/')[-1]
        in_assessment_indicator_filepath = download_dir+'/'+in_assessment_indicator_filename
        if os.path.exists(in_assessment_indicator_filepath):
            LOGGER.debug('Found: %s' % in_assessment_indicator_filepath)
        else:
            LOGGER.debug('Downloading from %s' % assessment_indicators_csv_url)
            resp = requests.get(assessment_indicators_csv_url)
            with open(in_assessment_indicator_filepath, 'w') as myfile:
                myfile.write(resp.content)
            LOGGER.debug('Downloaded to: %s' % in_assessment_indicator_filepath)

        # Where to store output data
        out_assessment_path = download_dir+'/Assessment-%s.csv' % self.job_id

        # Define paths to static helper paths depending on assessment_period
        path_input_data = self.config['input_path'].rstrip('/')
        if assessment_period == "1877-9999":
            in_helper_indicators_path = path_input_data+"/1877-9999/Configuration1877-9999_Indicators.csv"
            in_helper_indicatorunits_path = path_input_data+"/1877-9999/Configuration1877-9999_IndicatorUnits.csv"
        elif assessment_period == "2011-2016":
            in_helper_indicators_path = path_input_data+"/2011-2016/Configuration2011-2016_Indicators.csv"
            in_helper_indicatorunits_path = path_input_data+"/2011-2016/Configuration2011-2016_IndicatorUnits.csv"
        elif assessment_period == "2016-2021":
            in_helper_indicators_path = path_input_data+"/2016-2021/Configuration2016-2021_Indicators.csv"
            in_helper_indicatorunits_path = path_input_data+"/2016-2021/Configuration2016-2021_IndicatorUnits.csv"


        # Actually call R script:
        r_file_name = 'HEAT_subpart5.R'
        path_r_scripts = self.config['r_script_dir'].rstrip('/')
        r_args = [in_assessment_indicator_filepath, in_helper_indicators_path, in_helper_indicatorunits_path, out_assessment_path]
        returncode, stdout, stderr, err_msg  = call_r_script(LOGGER, r_file_name, path_r_scripts, r_args)
        # There is just one result:
        # * Assessment.csv


        # Return R error message if exit code not 0:
        if not returncode == 0:
            raise ProcessorExecuteError(user_msg = err_msg)


        ######################
        ### Return results ###
        ######################

        # Return output csv file as string directly in HTTP payload:
        # TODO check requested_outputs for user preference!
        if False:
            LOGGER.info('Reading result from R process from file "%s"' % out_assessment_path)
            with open(out_assessment_path, 'r') as mycsv:
                resultfilecontent = mycsv.read()
            return 'text/csv', resultfilecontent


        # Or return link to output csv file and return it wrapped in JSON:
        outputs = {
            "outputs": {
                "assessment": {
                    "title": PROCESS_METADATA['outputs']['assessment']['title'],
                    "description": PROCESS_METADATA['outputs']['assessment']['description'],
                    "href": self.config['download_url'].rstrip('/')+'/'+out_assessment_path.split('/')[-1]
                }
            }
        }

        return 'application/json', outputs




