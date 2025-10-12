import logging
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError
LOGGER = logging.getLogger(__name__)

import json
import os
import traceback
import zipfile
import glob
import geopandas as gpd
from pygeoapi.process.HEAT.pygeoapi_processes.docker_utils import run_docker_container2
from pygeoapi.process.HEAT.pygeoapi_processes.heat_utils import get_config_file_path
from pygeoapi.process.HEAT.pygeoapi_processes.heat_utils import download_zipped_data
from pygeoapi.process.HEAT.pygeoapi_processes.heat_utils import download_file



'''
## Testing with dummy spatial units and dummy grid sizes
## (created on QGIS; they don't make any sense in the real world, except being located in the Baltic Sea)
# Tested 2025-10-12
curl -X POST https://${PYSERVER}/processes/heat1advanced/execution \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "spatial_units": "https://aquainfra.ogc.igb-berlin.de/exampledata/helcom/dummy/dummytest_epsg4326_unitid.zip",
        "grid_size_table": "https://aquainfra.ogc.igb-berlin.de/exampledata/helcom/dummy/Configuration_dummy_UnitGridSize.csv"
    }
}'; date

## This one, with test inputs provided by HELCOM, leads to an error due to the input data format:
## GDAL Error 6: Geometry type of `3D Polygon' not supported in shapefiles.
curl -X POST https://${PYSERVER}/processes/heat1advanced/execution \
--header 'Content-Type: application/json' \
--data '{
    "inputs": {
        "spatial_units": "https://drive.usercontent.google.com/download?id=17o252m1oKsycLrPi434scwVoAJkZCQU3&export=download&authuser=0",
        "grid_size_table": "https://drive.usercontent.google.com/download?id=1kOJRQbuGJkDNiRdQsRtjsdBSGc-3SJ4R&export=download&authuser=0"
    }
}'; date

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

        # Where to store input data (will be mounted read-write into container):
        input_dir = f'{self.download_dir}/in/{self.process_id}_job_{self.job_id}'
        os.makedirs(input_dir, exist_ok=True)

        # Directory where static input data can be found (will be mounted readonly into container):
        #readonly_dir = self.inputs_read_only
        readonly_dir = None # not needed, so will not be mounted!

        ## Download input shape:
        ## Download config table (instead of retrieving from static data)...
        ## Downloading was moved into the R script that happens inside the R script!


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
        out_units_gridded_filepath = f'{output_dir}/units_gridded-{self.job_id}.shp'
        out_units_cleaned_filepath = f'{output_dir}/units_cleaned-{self.job_id}.shp'

        # Where to access output data
        out_units_gridded_url = out_units_gridded_filepath.replace(self.download_dir, self.download_url)
        out_units_cleaned_url = out_units_cleaned_filepath.replace(self.download_dir, self.download_url)


        ###########
        ### Run ###
        ###########

        # Actually call R script:
        script_name = 'run_heat1_csv_generic.R'
        r_args = [
            input_dir,
            spatial_units_url,
            grid_size_table_url,
            out_units_cleaned_filepath,
            out_units_gridded_filepath
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

        # Return a link to the viewer:
        filename = 'units_gridded'
        viewer_url = self.download_url.replace('/download', '')
        viewer_url += f'/viewer.html?filebase={filename}&job_id={self.job_id}&process_id={self.process_id}'



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
                    "href_geojson": geojson_url,
                    "href_viewer": viewer_url
                },
                "units_cleaned": {
                    "title": PROCESS_METADATA['outputs']['units_cleaned']['title'],
                    "description": PROCESS_METADATA['outputs']['units_cleaned']['description'],
                    "href": out_units_cleaned_url
                }
            }
        }

        return 'application/json', outputs

