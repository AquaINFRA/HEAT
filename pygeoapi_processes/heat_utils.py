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
        if not stripped_subdomains in allowed_download_hosts:
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

