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
curl -X POST "http://localhost:5000/processes/heat_4/execution" -H "Content-Type: application/json" -d "{\"inputs\":{\"assessment_period\": \"2016-2021\", \"annual_indicators\": \"https://testserver.com/download/AnnualIndicators-530d0014-836c-11ef-8e41-e14810fdd7f8.csv\"}}"


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
        config_file_path = os.environ.get('HELCOM_CONFIG_FILE', "./config.json")
        with open(config_file_path, 'r') as config_file:
            self.config = json.load(config_file)['helcom_heat']

    def set_job_id(self, job_id: str):
        self.job_id = job_id

    def __repr__(self):
        return f'<HEAT4Processor> {self.name}'


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
        assessment_period = data.get('assessment_period')
        annual_indicators_csv_url = data.get('annual_indicators') # get url!!

        # Check user inputs:
        if annual_indicators_csv_url is None:
            raise ProcessorExecuteError('Missing parameter "annual_indicators". Please provide a URL to your input data.')
        if assessment_period is None:
            raise ProcessorExecuteError('Missing parameter "assessment_period". Please provide a string.')

        # Check validity of argument:
        valid_assessment_period = ["1877-9999", "2011-2016", "2016-2021"]
        if not assessment_period in valid_assessment_period:
            raise ValueError('assessment_period is "%s", must be one of: %s' % (assessment_period, valid_assessment_period))

        # Where to look for input data
        # TODO check url outrs?
        download_dir = self.config["download_dir"].rstrip('/')
        in_annual_indicator_filename = annual_indicators_csv_url.split('/')[-1]
        in_annual_indicator_filepath = download_dir+'/'+in_annual_indicator_filename
        if os.path.exists(in_annual_indicator_filepath):
            LOGGER.debug('Found: %s' % in_annual_indicator_filepath)
        else:
            LOGGER.debug('Downloading: %s' % in_annual_indicator_filepath)
            resp = requests.get(annual_indicators_csv_url)
            with open(in_annual_indicator_filepath, 'w') as myfile:
                myfile.write(resp.content)

            LOGGER.debug('Downloaded: %s' % in_annual_indicator_filepath)

        # Where to store output data
        out_assessment_indicators_filepath = download_dir+'/AssessmentIndicators-%s.csv' % self.job_id

        # Define input file paths: Config file (indicators)
        path_input_data = self.config['input_path'].rstrip('/')
        if assessment_period == "1877-9999":
            in_helper_indicators_path = path_input_data+os.sep+"1877-9999/Configuration1877-9999_Indicators.csv"
            in_helper_indicatorunits_path = path_input_data+os.sep+"1877-9999/Configuration1877-9999_IndicatorUnits.csv"
        elif assessment_period == "2011-2016":
            in_helper_indicators_path = path_input_data+os.sep+"2011-2016/Configuration2011-2016_Indicators.csv"
            in_helper_indicatorunits_path = path_input_data+os.sep+"2011-2016/Configuration2011-2016_IndicatorUnits.csv"
        elif assessment_period == "2016-2021":
            in_helper_indicators_path = path_input_data+os.sep+"2016-2021/Configuration2016-2021_Indicators.csv"
            in_helper_indicatorunits_path = path_input_data+os.sep+"2016-2021/Configuration2016-2021_IndicatorUnits.csv"


        # Actually call R script:
        r_file_name = 'HEAT_subpart4_wk5.R'
        path_r_scripts = self.config['r_script_dir'].rstrip('/')
        r_args = [in_annual_indicator_filepath, in_helper_indicators_path, in_helper_indicatorunits_path, out_assessment_indicators_filepath]
        returncode, stdout, stderr, err_msg = call_r_script(LOGGER, r_file_name, path_r_scripts, r_args)
        # There are no results, except for one CSV of the Assessment Indicator:
        # * AssessmentIndicators.csv


        # Return R error message if exit code not 0:
        if not returncode == 0:
            raise ProcessorExecuteError(user_msg = err_msg)



        ######################
        ### Return results ###
        ######################


        # Return output csv file as string directly in HTTP payload:
        # TODO check requested_outputs for user preference!
        if False:
            LOGGER.info('Reading result from R process from file "%s"' % out_assessment_indicators_filepath)
            with open(out_assessment_indicators_filepath, 'r') as mycsv:
                resultfilecontent = mycsv.read()
            return 'text/csv', resultfilecontent

        # Or return link to output csv files and return it wrapped in JSON:
        outputs = {
            "outputs": {
                "assessment_indicators": {
                    "title": PROCESS_METADATA['outputs']['assessment_indicators']['title'],
                    "description": PROCESS_METADATA['outputs']['assessment_indicators']['description'],
                    "href": self.config['download_url'].rstrip('/')+'/'+out_assessment_indicators_filepath.split('/')[-1]
                }
            }
        }

        return 'application/json', outputs

