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
curl -X POST "http://localhost:5000/processes/heat_1/execution" -H "Content-Type: application/json" -d "{\"inputs\":{\"assessment_period\": \"2016-2021\"}}"

'''


# Process metadata and description
# Has to be in a JSON file of the same name, in the same dir! 
script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))



class HEAT1Processor(BaseProcessor):

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
        return f'<HEAT1Processor> {self.name}'


    def execute(self, data):
        LOGGER.info('Starting process HEAT 1!')
        try:
            mimetype, result = self._execute(data)
            return mimetype, result

        except Exception as e:
            LOGGER.error(e)
            print(traceback.format_exc())
            raise ProcessorExecuteError(e)


    def _execute(self, data):

        # Get input:
        assessment_period = data.get('assessment_period')

        # Check user inputs:
        if assessment_period is None:
            raise ProcessorExecuteError('Missing parameter "assessment_period". Please provide a string.')

        # Check validity of argument:
        valid_assessment_periods = ["1877-9999", "2011-2016", "2016-2021"]
        if not assessment_period in valid_assessment_periods:
            raise ValueError('assessment_period is "%s", must be one of: %s' % (assessment_period, valid_assessment_periods))

        # Where to store output data
        download_dir = self.config["download_dir"].rstrip('/')
        out_units_gridded_filepath = download_dir+'/units_gridded-%s.shp' % self.job_id
        out_units_cleaned_filepath = download_dir+'/units_cleaned-%s.shp' % self.job_id


        # Define paths to static helper paths depending on assessment_period
        path_input_data = self.config['input_path'].rstrip('/')
        if assessment_period == "1877-9999":
            in_helper_units_path = path_input_data+os.sep+"1877-9999/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022_eutro.shp"
            in_helper_gridsizes_path = path_input_data+os.sep+"1877-9999/Configuration1877-9999_UnitGridSize.csv"
        elif assessment_period == "2011-2016":
            in_helper_units_path = path_input_data+os.sep+"2011-2016/AssessmentUnits.shp"
            in_helper_gridsizes_path = path_input_data+os.sep+"2011-2016/Configuration2011-2016_UnitGridSize.csv"
        elif assessment_period == "2016-2021":
            in_helper_units_path = path_input_data+os.sep+"2016-2021/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022_eutro.shp"
            in_helper_gridsizes_path = path_input_data+os.sep+"2016-2021/Configuration2016-2021_UnitGridSize.csv"


        # Actually call R script:
        r_file_name = 'HEAT_subpart1_gridunits.R'
        path_rscripts = self.config['r_script_dir'].rstrip('/')
        r_args = [assessment_period, in_helper_units_path, in_helper_gridsizes_path, out_units_cleaned_filepath, out_units_gridded_filepath]
        returncode, stdout, stderr, err_msg = call_r_script(LOGGER, r_file_name, path_rscripts, r_args)
        # The results are two shapefiles:
        # * units_cleaned.shp
        # * units_gridded.shp
        # and five maps of the Assessment Units:
        # * Assessment_Units.png
        # * Assessment_GridUnits10.png
        # * Assessment_GridUnits30.png
        # * Assessment_GridUnits60.png
        # * Assessment_GridUnits.png
        # TODO Discuss: Return maps as GeoJSON? Those are static, could just be downloaded. Unless we allow other assessment units one day.


        # Return R error message if exit code not 0:
        if not returncode == 0:
            raise ProcessorExecuteError(user_msg = err_msg)


        ######################
        ### Return results ###
        ######################

        # Return output csv file as string directly in HTTP payload:
        # TODO check requested_outputs for user preference!
        
        # Or return link to output csv file and return it wrapped in JSON:
        # TODO: add png, maybe cleaned
        # TODO: Returning shp makes no sense without all the other files!!! 
        outputs = {
            "outputs": {
                "units_gridded": {
                    "title": PROCESS_METADATA['outputs']['units_gridded']['title'],
                    "description": PROCESS_METADATA['outputs']['units_gridded']['description'],
                    "href": self.config['download_url'].rstrip('/')+'/'+out_units_gridded_filepath.split('/')[-1]
                },
                "units_cleaned": {
                    "title": PROCESS_METADATA['outputs']['units_cleaned']['title'],
                    "description": PROCESS_METADATA['outputs']['units_cleaned']['description'],
                    "href": self.config['download_url'].rstrip('/')+'/'+out_units_cleaned_filepath.split('/')[-1]
                }
            }
        }

        return 'application/json', outputs
