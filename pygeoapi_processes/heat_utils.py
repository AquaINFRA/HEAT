import requests
import zipfile
import os
import json
from urllib.parse import urlparse
import logging
LOGGER = logging.getLogger(__name__)
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError



def get_config_file_path(which_config, assessment_period, path_input_data):

    if not which_config in ['Indicators', 'IndicatorUnits', 'IndicatorUnitResults', 'UnitGridSize']:
        err_msg = 'Trying to retrieve unknown config file: %s' % which_config
        LOGGER.error(err_msg)
        raise ValueError(err_msg)

    if assessment_period == "1877-9999":
        return path_input_data+"/adapted_inputs/1877-9999/Configuration1877-9999_%s.csv" % which_config
    elif assessment_period == "2011-2016":
        return path_input_data+"/adapted_inputs/2011-2016/Configuration2011-2016_%s.csv" % which_config
    elif assessment_period == "2016-2021":
        return path_input_data+"/adapted_inputs/2016-2021/Configuration2016-2021_%s.csv" % which_config


def download_file(data_url, download_dir, filename):
    # TODO: Make better download function! SAFER!

    LOGGER.debug('Downloading file: %s from %s' % (filename, data_url))

    if not (data_url.startswith('http://') or data_url.startswith('https://')):
        err_msg = "Cannot download. URL lacks http/https: %s" % data_url
        LOGGER.error(err_msg)
        raise ValueError(err_msg)

    # Read config:
    config_file_path = os.environ.get('AQUAINFRA_CONFIG_FILE', "./config.json")
    try:
        with open(config_file_path, 'r') as config_file:
            config = json.load(config_file)
            allowed_download_hosts = config["helcom_heat"]["download_whitelist"]
    except KeyError:
        err_msg = 'Cannot download. No download whitelist defined in config file.'
        LOGGER.error(err_msg)
        raise ValueError(err_msg)

    # Check if the URL's hostname is in the whitelist:
    parsed_url = urlparse(data_url)
    if not parsed_url.hostname in allowed_download_hosts:
        LOGGER.debug('Not in whitelist: %s' % parsed_url.hostname)
        stripped_subdomains = '.'.join(parsed_url.hostname.split(".")[-2:])
        if stripped_subdomains in allowed_download_hosts:
            LOGGER.debug('Is in whitelist:  %s' % stripped_subdomains)
        else:
            LOGGER.debug('Not in whitelist: %s' % stripped_subdomains)
            err_msg = "Currently not allowed: Downloading from %s. Host not in whitelist." % parsed_url.hostname
            LOGGER.error(err_msg)
            raise NotImplementedError(err_msg)

    #raise NotImplementedError("Need to implement download inside container...")
    # TODO: If the download URL is from our domain, it might be the result of a previous tool, and we
    # could re-use instead of download...
    data_path = download_dir.rstrip("/")+'/'+filename
    resp = requests.get(data_url)
    if not resp.status_code == 200:
        raise ProcessorExecuteError('Could not download input file (HTTP status %s): %s' % (resp.status_code, data_url))

    with open(data_path, 'wb') as myfile:
        for chunk in resp.iter_content(chunk_size=1024):
            if chunk:
                myfile.write(chunk)

    LOGGER.debug('Downloaded to: %s' % data_path)
    return data_path


def download_zipped_data(data_url, download_dir, filename, suffix="csv"):
    #filename = data_url.split('/')[-1]
    LOGGER.debug('Downloading zipped file: %s from %s' % (filename, data_url))

    data_path = download_file(data_url, download_dir, filename)

    ## Unzip downloaded data, if zipped, and return the first csv file found
    ## in the unzipped directory...
    ## TODO: Potentially unsafe, move to inside container!
    if not zipfile.is_zipfile(data_path):
        return data_path
    else:
        data_path_unzipped = download_dir.rstrip("/")+'/unzipped_'+filename
        LOGGER.debug('Unzipping to %s' % data_path_unzipped)
        with zipfile.ZipFile(data_path, 'r') as zip_ref:
            zip_ref.extractall(data_path_unzipped)

        for item in os.listdir(data_path_unzipped):
            if item.endswith('.'+suffix):
                data_path = data_path_unzipped.rstrip('/')+'/'+item
                LOGGER.debug('Will use this file from unzipped dir: %s' % data_path)
                return data_path

        err_msg = 'No %s file found in unzipped data...' % suffix
        LOGGER.error(err_msg)
        raise ProcessorExecuteError(err_msg)


def zip_a_shapefile(full_path):

    shapefile_extensions = [".shp", ".shx", ".dbf", ".prj", ".cpg"]

    # If we know dir and filename separately:
    #basename = filename.replace('shp', '')

    # If we know the path of the shapefile:
    containing_dir = os.path.dirname(full_path)
    basename_with_ext = os.path.basename(full_path)
    basename = os.path.splitext(basename_with_ext)[0]

    # Path to the zip file to create
    zip_path = os.path.join(containing_dir, f"{basename}.zip")

    # Create the zip file
    with zipfile.ZipFile(zip_path, "w") as zipf:
        for ext in shapefile_extensions:
            file_path = os.path.join(containing_dir, f"{basename}{ext}")
            if os.path.exists(file_path):
                zipf.write(file_path, arcname=os.path.basename(file_path))

    LOGGER.debug(f"Zipped shapefile written to: {zip_path}")
    return zip_path


def get_path_default_units(assessment_period, readonly_dir):

    if assessment_period == "1877-9999":
        return readonly_dir+"/original_inputs/1877-9999/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022_eutro.shp"
    elif assessment_period == "2011-2016":
        return readonly_dir+"/original_inputs/2011-2016/AssessmentUnits.shp"
    elif assessment_period == "2016-2021":
        return readonly_dir+"/original_inputs/2016-2021/HELCOM_subbasin_with_coastal_WFD_waterbodies_or_watertypes_2022_eutro.shp"


def get_path_default_gridded_units(assessment_period, readonly_dir):

    if assessment_period == "1877-9999":
        return readonly_dir+"/adapted_inputs/1877-9999/units_gridded.shp"
    elif assessment_period == "2011-2016":
        return readonly_dir+"/adapted_inputs/2011-2016/units_gridded.shp"
    elif assessment_period == "2016-2021":
        return readonly_dir+"/adapted_inputs/2016-2021/units_gridded.shp"


def get_path_default_cleaned_units(assessment_period, readonly_dir):

    if assessment_period == "1877-9999":
        return readonly_dir+"/adapted_inputs/1877-9999/units_cleaned.shp"
    elif assessment_period == "2011-2016":
        return readonly_dir+"/adapted_inputs/2011-2016/units_cleaned.shp"
    elif assessment_period == "2016-2021":
        return readonly_dir+"/adapted_inputs/2016-2021/units_cleaned.shp"


def get_path_default_bottle_data(assessment_period, readonly_dir):

    if assessment_period == "1877-9999":
        return readonly_dir+"/original_inputs/1877-9999/StationSamples1877-9999BOT_2022-12-09.txt.gz"
    elif assessment_period == "2011-2016":
        return readonly_dir+"/original_inputs/2011-2016/StationSamples2011-2016BOT_2022-12-09.txt.gz"
    elif assessment_period == "2016-2021":
        return readonly_dir+"/original_inputs/2016-2021/StationSamples2016-2021BOT_2022-12-09.txt.gz"


def get_path_default_pmp_data(assessment_period, readonly_dir):

    if assessment_period == "1877-9999":
        return readonly_dir+"/original_inputs/1877-9999/StationSamples1877-9999PMP_2022-12-09.txt.gz"
    elif assessment_period == "2011-2016":
        return readonly_dir+"/original_inputs/2011-2016/StationSamples2011-2016PMP_2022-12-09.txt.gz"
    elif assessment_period == "2016-2021":
        return readonly_dir+"/original_inputs/2016-2021/StationSamples2016-2021PMP_2022-12-09.txt.gz"


def get_path_default_ctd_data(assessment_period, readonly_dir):

    if assessment_period == "1877-9999":
        return readonly_dir+"/original_inputs/1877-9999/StationSamples1877-9999CTD_2022-12-09.txt.gz"
    elif assessment_period == "2011-2016":
        return readonly_dir+"/original_inputs/2011-2016/StationSamples2011-2016CTD_2022-12-09.txt.gz"
    elif assessment_period == "2016-2021":
        return readonly_dir+"/original_inputs/2016-2021/StationSamples2016-2021CTD_2022-12-09.txt.gz"


def get_path_bottle_input_data(assessment_period, bot_url, readonly_dir, target_dir):

    if bot_url is None:
        # If the user passed nothing or "null", no bottle data is used!
        # TODO: Dont return/store results for BOT, if no bottle inputs are given!
        return None

    elif bot_url is not None and bot_url.lower() == 'default':
        LOGGER.info('Client did not provide bottle data, using pre-stored ones...')
        bot_path = get_path_default_bottle_data(assessment_period, readonly_dir)
        return bot_path

    elif bot_url is not None and bot_url.startswith('http'):
        LOGGER.info('Client requested bottle data: %s' % bot_url)
        #raise NotImplementedError("Currently, only default bottle data can be used!")
        # TODO: Ideally, the download should not happen here (in the process python file), but
        # inside the docker container.
        filename = bot_url.split('/')[-1]
        bot_path = download_zipped_data(bot_url, target_dir, filename, suffix="csv")
        # TODO: /out/ is for the outputs, the inputs should be downloaded inside the container to /in, which is
        # not mounted. So temporarily, I will download this input to /out, just so it gets mounted...
        return bot_path

    else:
        err_msg = 'Could not understand bottle data: %s' % bot_url
        LOGGER.error(err_msg)
        raise ProcessorExecuteError(err_msg)


def get_path_pmp_input_data(assessment_period, pmp_url, readonly_dir, target_dir):

    if pmp_url is None:
        # If the user passed nothing or "null", no pump data is used!
        # TODO: Dont return/store results for PMP, if no PMP inputs are given!
        return None

    elif pmp_url.lower() == 'default':
        LOGGER.info('Client did not provide pump data, using pre-stored ones...')
        pmp_path = get_path_default_pmp_data(assessment_period, readonly_dir)
        return pmp_path

    elif pmp_url is not None and pmp_url.startswith('http'):
        LOGGER.info('Client requested pump data: %s' % pmp_url)
        #raise NotImplementedError("Currently, only default pump data can be used!")
        # TODO: Ideally, the download should not happen here (in the process python file), but
        # inside the docker container.
        filename = pmp_url.split('/')[-1]
        pmp_path = download_zipped_data(pmp_url, target_dir, filename, suffix="csv")
        # TODO: /out/ is for the outputs, the inputs should be downloaded inside the container to /in, which is
        # not mounted. So temporarily, I will download this input to /out, just so it gets mounted...
        return pmp_path

    else:
        err_msg = 'Could not understand pump data: %s' % pmp_url
        LOGGER.error(err_msg)
        raise ProcessorExecuteError(err_msg)


def get_path_ctd_input_data(assessment_period, ctd_url, readonly_dir, target_dir):

    if ctd_url is None:
        # If the user passed nothing or "null", no pump data is used!
        # TODO: Dont return/store results for CTD, if no CTD inputs are given!
        return None

    elif ctd_url.lower() == 'default':
        LOGGER.info('Client did not provide ctd data, using pre-stored ones...')
        ctd_path = get_path_default_pmp_data(assessment_period, readonly_dir)
        return ctd_path

    elif ctd_url is not None and ctd_url.startswith('http'):
        LOGGER.info('Client requested ctd data: %s' % ctd_url)
        #raise NotImplementedError("Currently, only default ctd data can be used!")
        # TODO: Ideally, the download should not happen here (in the process python file), but
        # inside the docker container.
        filename = ctd_url.split('/')[-1]
        ctd_path = download_zipped_data(ctd_url, target_dir, filename, suffix="csv")
        # TODO: /out/ is for the outputs, the inputs should be downloaded inside the container to /in, which is
        # not mounted. So temporarily, I will download this input to /out, just so it gets mounted...
        return ctd_path

    else:
        err_msg = 'Could not understand ctd data: %s' % ctd_url
        LOGGER.error(err_msg)
        raise ProcessorExecuteError(err_msg)

