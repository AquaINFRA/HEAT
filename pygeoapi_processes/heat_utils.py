import requests
import logging
LOGGER = logging.getLogger(__name__)

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
    if not "igb-berlin.de" in data_url:
        # This is super stupid, as it can easily be faked... TODO!!!!
        raise NotImplementedError("Currently not allowed")

    #raise NotImplementedError("Need to implement download inside container...")
    # TODO: If the download URL is from our domain, it might be the result of a previous tool, and we
    # could re-use instead of download...
    data_path = download_dir+'/'+filename
    LOGGER.debug('Downloading file: %s from %s' % (filename, data_url))
    resp = requests.get(data_url)
    if not resp.status_code == 200:
        raise ProcessorExecuteError('Could not download input file (HTTP status %s): %s' % (resp.status_code, data_url))

    with open(data_path, 'wb') as myfile:
        for chunk in resp.iter_content(chunk_size=1024):
            if chunk:
                myfile.write(chunk)

    LOGGER.debug('Downloaded to: %s' % data_path)
    return data_path
