import logging
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError
LOGGER = logging.getLogger(__name__)

import json
import zipfile
import glob
import os
import traceback
import geopandas as gpd
from pygeoapi.process.HEAT.pygeoapi_processes.docker_utils import run_docker_container
from pygeoapi.process.HEAT.pygeoapi_processes.heat_utils import get_config_file_path


'''
curl -X POST 'https://localhost:5000/processes/heat1/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "assessment_period": "holas-2"
    }
}'

# This one will complain:
curl -X POST 'https://localhost:5000/processes/heat1/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "assessment_period": "2016-2021"
    }
}'

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

        ##############
        ### Inputs ###
        ##############

        # Retrieve user inputs:
        assessment_period = data.get('assessment_period').lower()

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

        # Define paths to static input paths depending on assessment_period
        in_unitsFilePath = get_unit_file_path(assessment_period, path_input_data)
        in_unitGridSizePath = get_config_file_path('UnitGridSize', assessment_period, path_input_data)


        ###############
        ### Outputs ###
        ###############

        # Where to store output data
        out_units_gridded_filepath = self.download_dir+'/out/units_gridded-%s.shp' % self.job_id
        out_units_cleaned_filepath = self.download_dir+'/out/units_cleaned-%s.shp' % self.job_id

        # Where to access output data
        out_units_gridded_url      = self.download_url+'/out/units_gridded-%s.shp' % self.job_id
        out_units_cleaned_url      = self.download_url+'/out/units_cleaned-%s.shp' % self.job_id


        ###########
        ### Run ###
        ###########

        # Actually call R script:
        script_name = 'run_heat1_csv.R'
        r_args = [assessment_period, in_unitsFilePath, in_unitGridSizePath, out_units_cleaned_filepath, out_units_gridded_filepath]
        returncode, stdout, stderr, user_err_msg = run_docker_container(
            self.docker_executable,
            self.image_name,
            script_name,
            self.job_id,
            self.download_dir,
            self.inputs_read_only,
            r_args
        )
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
            raise ProcessorExecuteError(user_msg = user_err_msg)


        ###################
        ### Zip results ###
        ###################

        # Find the files (parts of shape...)
        dir_name = os.path.dirname(out_units_gridded_filepath)
        base_name = os.path.splitext(os.path.basename(out_units_gridded_filepath))[0]
        pattern = os.path.join(dir_name, f"{base_name}.*")
        out_units_gridded_files_all = glob.glob(pattern)
        LOGGER.debug('All gridded: %s' % out_units_gridded_files_all)
        dir_name = os.path.dirname(out_units_gridded_filepath)
        base_name = os.path.splitext(os.path.basename(out_units_cleaned_filepath))[0]
        pattern = os.path.join(dir_name, f"{base_name}.*")
        out_units_cleaned_files_all = glob.glob(pattern)
        LOGGER.debug('All cleaned: %s' % out_units_cleaned_files_all)

        # Zip the files:
        zipname_gridded = out_units_gridded_filepath.replace("shp", "zip")
        zipname_cleaned = out_units_cleaned_filepath.replace("shp", "zip")
        LOGGER.debug('Names: %s, %s' % (zipname_gridded, zipname_cleaned))
        #shutil.make_archive(zipname_gridded, "zip", out_units_gridded_files_all)
        #shutil.make_archive(zipname_cleaned, "zip", out_units_cleaned_files_all)
        with zipfile.ZipFile(zipname_gridded, 'w') as zipf:
            for file in out_units_gridded_files_all:
                arcname = os.path.basename(file)  # Optional: store without full path
                zipf.write(file, arcname=arcname)
        with zipfile.ZipFile(zipname_cleaned, 'w') as zipf:
            for file in out_units_cleaned_files_all:
                arcname = os.path.basename(file)  # Optional: store without full path
                zipf.write(file, arcname=arcname)

        # Fix URLs:
        out_units_gridded_url = out_units_gridded_url.replace("shp", "zip")
        out_units_cleaned_url = out_units_cleaned_url.replace("shp", "zip")

        ########################
        ### Generate GeoJSON ###
        ########################

        # Read spatial units from shapefile:
        LOGGER.debug('Make GeoJSON from Shapefile...')
        gdf = gpd.read_file(out_units_gridded_filepath)
        gdf_4326 = gdf.to_crs(epsg=4326)

        # Write spatial units to geojson file:
        geojson_path = out_units_gridded_filepath.replace("shp", "json")
        gdf_4326.to_file(geojson_path, driver='GeoJSON')

        # Return GeoJSON directly: It tends to be very long, so bad idea!
        #with open(geojson_path, 'r') as myfile:
        #    geojson_directly = json.load(myfile)

        # Return link to GeoJSON file:
        geojson_url = out_units_gridded_url.replace("zip", "json")


        ######################
        ### Return results ###
        ######################

        # Return link to output csv files and return it wrapped in JSON:
        # TODO: add png, maybe cleaned
        outputs = {
            "outputs": {
                "units_gridded": {
                    "title": PROCESS_METADATA['outputs']['units_gridded']['title'],
                    "description": PROCESS_METADATA['outputs']['units_gridded']['description'],
                    "href": out_units_gridded_url,
                    "href_geojson": geojson_url
                },
                "units_cleaned": {
                    "title": PROCESS_METADATA['outputs']['units_cleaned']['title'],
                    "description": PROCESS_METADATA['outputs']['units_cleaned']['description'],
                    "href": out_units_cleaned_url
                }
            }
        }

        return 'application/json', outputs


def get_unit_file_path(assessment_period, path_input_data):

    if assessment_period == "1877-9999":
        return path_input_data+"/original_inputs/1877-9999/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022_eutro.shp"
    elif assessment_period == "2011-2016":
        return path_input_data+"/original_inputs/2011-2016/AssessmentUnits.shp"
    elif assessment_period == "2016-2021":
        return path_input_data+"/original_inputs/2016-2021/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022_eutro.shp"

