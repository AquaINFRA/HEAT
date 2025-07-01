import logging
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError
LOGGER = logging.getLogger(__name__)

import json
import os
import traceback
import zipfile
import glob
from pygeoapi.process.HEAT.pygeoapi_processes.docker_utils import run_docker_container
from pygeoapi.process.HEAT.pygeoapi_processes.heat_utils import get_config_file_path
from pygeoapi.process.HEAT.pygeoapi_processes.heat_utils import download_zipped_data
from pygeoapi.process.HEAT.pygeoapi_processes.heat_utils import download_file



'''
curl -X POST 'https://localhost:5000/processes/heat1/execution' \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "spatial_units": "https://example.com/download/myregions.shp.zip",
        "grid_size_table": "https://example.com/download/mygridsizes.csv"
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
        spatial_units_url = data.get('spatial_units')
        grid_size_table_url = data.get('grid_size_table')

        # Check user inputs:
        if spatial_units_url is None:
            raise ProcessorExecuteError('Missing parameter "spatial_units". Please provide URL.')
        if grid_size_table_url is None:
            raise ProcessorExecuteError('Missing parameter "grid_size_table". Please provide URL.')

        ##################
        ### Input data ###
        ##################

        # Directory where static input data can be found. It will be mounted read-only to the container:
        path_input_data = self.inputs_read_only

        ## Download input shape:
        in_unitsFileName = spatial_units_url.split('/')[-1]
        #in_unitsGriddedFilePath = download_file(units_gridded_url, self.download_dir+'/out/', in_unitsGriddedFileName)
        ## TODO: Zipped shapes, be careful!!
        in_unitsFilePath = download_zipped_data(spatial_units_url, self.download_dir+'/out/', in_unitsFileName, suffix="shp")

        # Download config table (instead of retrieving from static data)...
        in_unitGridSizePath = download_file(grid_size_table_url, self.download_dir+'/out/', 'gridsizes-%s.csv' % self.job_id)


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
        script_name = 'run_heat1_csv_generic.R'
        r_args = [in_unitsFilePath, in_unitGridSizePath, out_units_cleaned_filepath, out_units_gridded_filepath]
        returncode, stdout, stderr, user_err_msg = run_docker_container(
            self.docker_executable,
            self.image_name,
            script_name,
            self.job_id,
            self.download_dir,
            self.inputs_read_only,
            r_args
        )
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
                    "href": out_units_gridded_url
                },
                "units_cleaned": {
                    "title": PROCESS_METADATA['outputs']['units_cleaned']['title'],
                    "description": PROCESS_METADATA['outputs']['units_cleaned']['description'],
                    "href": out_units_cleaned_url
                }
            }
        }

        return 'application/json', outputs

