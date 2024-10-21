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
curl -X POST "https://localhost:5000/processes/heat_3_advanced/execution" -H "Content-Type: application/json" -d "{\"inputs\":{\"assessment_period\": \"2016-2021\", \"combined_Chlorophylla_IsWeighted\": true, \"samples\": \"https://testserver.com/download/StationSamples-f04c9a56-838a-11ef-8e41-e14810fdd7f8.csv\"}}"


'''


# Process metadata and description
# Has to be in a JSON file of the same name, in the same dir! 
script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))

class HEAT3AdvancedProcessor(BaseProcessor):

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
        return f'<HEAT3AdvancedProcessor> {self.name}'


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

        # User input:
        table_indicators = data.get('table_indicators')
        table_indicator_units = data.get('table_indicator_units')
        table_indicator_unit_results = data.get('table_indicator_unit_results')
        spatial_units = data.get('spatial_units')
        combined_Chlorophylla_IsWeighted = data.get('combined_Chlorophylla_IsWeighted')
        LOGGER.debug('Chlorophyll flag: %s %s' % (combined_Chlorophylla_IsWeighted, type(combined_Chlorophylla_IsWeighted)))

        # Check user inputs:
        if samples_url is None:
            raise ProcessorExecuteError('Missing parameter "samples". Please provide a URL to your input data.')
        #if assessment_period is None:
        #    raise ProcessorExecuteError('Missing parameter "assessment_period". Please provide a string.')
        if combined_Chlorophylla_IsWeighted is None:
            raise ProcessorExecuteError('Missing parameter "combined_Chlorophylla_IsWeighted". Please provide an boolean.')


        raise ProcessorExecuteError('NOT IMPLEMENTED: HEAT 3 Advanced mode is not implemented yet. Please use HOLAS mode as of now. Thanks!')

        # Check validity of argument:
        #valid_assessment_periods = ["1877-9999", "2011-2016", "2016-2021"]
        #if not assessment_period in valid_assessment_periods:
        #    raise ValueError('assessment_period is "%s", must be one of: %s' % (assessment_period, valid_assessment_periods))

        # Download user-provided samples
        download_dir = self.config["download_dir"].rstrip('/')
        in_relevant_stationsamples_filepath = None
        LOGGER.info('Client requested sample data: %s' % samples_url)
        # TODO: Check if the url is OURS!!
        in_relevant_stationsamples_filename = samples_url.split('/')[-1]
        in_relevant_stationsamples_filepath = download_dir+'/'+in_relevant_stationsamples_filename
        if os.path.exists(in_relevant_stationsamples_filepath):
            LOGGER.debug('Found: %s' % in_relevant_stationsamples_filepath)
        else:
            LOGGER.debug('Downloading sample data: %s from %s' % (in_relevant_stationsamples_filename, samples_url))
            resp = requests.get(samples_url)
            with open(in_relevant_stationsamples_filepath, 'w') as myfile:
                myfile.write(resp.content)
                LOGGER.debug('Downloaded: %s' % in_relevant_stationsamples_filepath)

        # Where to look for cleaned units data
        in_units_cleaned_filepath = path_input_data+"/%s/units_cleaned.shp" % assessment_period

        # Where to store output data
        out_annual_indicators_filepath = download_dir+'/AnnualIndicators-%s.csv' % self.job_id

        # Define paths to static helper paths depending on assessment_period
        path_input_data = self.config['input_path'].rstrip('/')
        if assessment_period == "1877-9999":
            in_helper_indicators_path = path_input_data+"/1877-9999/Configuration1877-9999_Indicators.csv"
            in_helper_indicatorunits_path = path_input_data+"/1877-9999/Configuration1877-9999_IndicatorUnits.csv"
            in_helper_indicatorunitresults_path = path_input_data+"/1877-9999/Configuration1877-9999_IndicatorUnitResults.csv"
        elif assessment_period == "2011-2016":
            in_helper_indicators_path = path_input_data+"/2011-2016/Configuration2011-2016_Indicators.csv"
            in_helper_indicatorunits_path = path_input_data+"/2011-2016/Configuration2011-2016_IndicatorUnits.csv"
            in_helper_indicatorunitresults_path = path_input_data+"/2011-2016/Configuration2011-2016_IndicatorUnitResults.csv"
        elif assessment_period == "2016-2021":
            in_helper_indicators_path = path_input_data+"/2016-2021/Configuration2016-2021_Indicators.csv"
            in_helper_indicatorunits_path = path_input_data+"/2016-2021/Configuration2016-2021_IndicatorUnits.csv"
            in_helper_indicatorunitresults_path = path_input_data+"/2016-2021/Configuration2016-2021_IndicatorUnitResults.csv"
        
        ####################
        ### Run R Script ###
        ####################

        r_file_name = 'HEAT_subpart3_wk3.R'
        path_rscripts = self.config['r_script_dir'].rstrip('/')
        in_chlorophyll_flag = str(combined_Chlorophylla_IsWeighted).lower()
        LOGGER.debug('Chlorophyll flag now: %s %s' % (in_chlorophyll_flag, type(in_chlorophyll_flag)))
        r_args = [in_relevant_stationsamples_filepath, in_chlorophyll_flag, in_units_cleaned_filepath,
                  in_helper_indicators_path, in_helper_indicatorunits_path, in_helper_indicatorunitresults_path, out_annual_indicators_filepath]
        LOGGER.info('##### R-args:  %s' % r_args)
        returncode, stdout, stderr, err_msg = call_r_script(LOGGER, r_file_name, path_rscripts, r_args)
        # Result:
        # * AnnualIndicators.csv

        # Return R error message if exit code not 0:
        if not returncode == 0:
            raise ProcessorExecuteError(user_msg = err_msg)


        ######################
        ### Return results ###
        ######################

        # Return output csv file as string directly in HTTP payload:
        # TODO check requested_outputs for user preference!
        if False:        
            LOGGER.info('Reading result from R process from file "%s"' % out_annual_indicators_filepath)
            with open(out_annual_indicators_filepath, 'r') as mycsv:
                resultfilecontent = mycsv.read()
            return 'text/csv', resultfilecontent


        # Or return link to output csv file and return it wrapped in JSON:
        outputs = {
            "outputs": {
                "annual_indicators": {
                    "title": PROCESS_METADATA['outputs']['annual_indicators']['title'],
                    "description": PROCESS_METADATA['outputs']['annual_indicators']['description'],
                    "href": self.config['download_url'].rstrip('/')+'/'+out_annual_indicators_filepath.split('/')[-1]
                }
            }
        }

        return 'application/json', outputs


