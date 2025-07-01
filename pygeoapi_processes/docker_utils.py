import os
import subprocess
import logging
LOGGER = logging.getLogger(__name__)

def run_docker_container(
        docker_executable,
        image_name,
        script_name,
        random_string,
        download_dir,
        inputs_read_only,
        script_args
    ):
    LOGGER.debug('Prepare running docker container (image %s)' % image_name)

    # Create container name
    # Note: Only [a-zA-Z0-9][a-zA-Z0-9_.-] are allowed
    #container_name = "%s_%s" % (image_name.split(':')[0], os.urandom(5).hex())
    container_name = "%s_%s" % (image_name.split(':')[0], random_string)

    # Define paths inside the container
    container_out = '/out'
    container_in_readonly = '/readonly'

    # Define local paths
    local_out = os.path.join(download_dir, "out")

    # Ensure directories exist
    os.makedirs(local_out, exist_ok=True)

    # Replace paths in args:
    sanitized_args = []
    LOGGER.debug('Args before sanitizing: %s' % script_args)
    for arg in script_args:
        newarg = arg
        if arg is None:
            newarg = 'null'
            LOGGER.debug("Replaced argument %s by %s..." % (arg, newarg))
        elif type(arg) == type(True):
            LOGGER.debug('Found a boolean: %s' % arg)
            if arg == True:
                newarg = 'true'
            elif arg == False:
                newarg = 'false'
            LOGGER.debug("Replaced argument %s by %s..." % (arg, newarg))
        elif inputs_read_only in arg:
            newarg = arg.replace(inputs_read_only, container_in_readonly)
            LOGGER.debug("Replaced argument %s by %s..." % (arg, newarg))
        elif local_out in arg:
            newarg = arg.replace(local_out, container_out)
            LOGGER.debug("Replaced argument %s by %s..." % (arg, newarg))
        sanitized_args.append(newarg)

    # Prepare container command
    # (mount volumes etc.)
    docker_args = [
        docker_executable, "run",
        "--rm",
        "--name", container_name,
        "-v", f"{inputs_read_only}:{container_in_readonly}",
        "-v", f"{local_out}:{container_out}",
        "-e", f"SCRIPT={script_name}",
        image_name,
    ]
    docker_command = docker_args + sanitized_args
    LOGGER.debug('Docker command: %s' % docker_command)
    
    # Run container
    try:
        LOGGER.debug('Start running docker container (image %s)' % image_name)
        result = subprocess.run(docker_command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout = result.stdout.decode()
        stderr = result.stderr.decode()
        LOGGER.debug('Finished running docker container (image %s)' % image_name)
        log_all_docker_output(stdout, stderr)
        return result.returncode, stdout, stderr, "no error"

    except subprocess.CalledProcessError as e:
        returncode = e.returncode
        stdout = e.stdout.decode()
        stderr = e.stderr.decode()
        LOGGER.error('Failed running docker container (exit code %s)' % returncode)
        user_err_msg = get_error_message_from_docker_stderr(stderr)
        return returncode, stdout, stderr, user_err_msg


def log_all_docker_output(stdout, stderr):

    for line in stdout.split('\n'):
        if line:
            LOGGER.debug('Docker stdout: %s' % line)

    for line in stderr.split('\n'):
        if line:
            LOGGER.debug('Docker stderr: %s' % line)


def get_error_message_from_docker_stderr(stderr, log_all_lines = True):
    '''
    We would like to return meaningful messages to users. For example, by
    printing ALL stderr lines, we get the following:

    ERROR - Docker stderr: Error in if (zz[which.max(zz)] < minpts) stop("All species do not have enough data after removing missing values and duplicates.") : 
    ERROR - Docker stderr:   argument is of length zero
    ERROR - Docker stderr: Calls: pred_extract
    ERROR - Docker stderr: Execution halted

    ERROR - Docker stderr: Error in pred_extract(data = speciesfiltered, raster = worldclim, lat = in_colname_lat,  : 
    ERROR - Docker stderr:   All species do not have enough data after removing missing values and duplicates.
    ERROR - Docker stderr: Execution halted

    Now, how to capture the meaningful part of that, which we want to return
    to the user? Here is a first attempt:
    '''

    user_err_msg = ""
    error_on_previous_line = False
    colon_on_previous_line = False
    for line in stderr.split('\n'):

        # Skip empty lines:
        if not line:
            continue

        # Print all non-empty lines to log:
        if log_all_lines:
            LOGGER.error('Docker stderr: %s' % line)

        # R error messages may start with the word "Error"
        if line.startswith("Error") or line.startswith("Fatal error"):
            #LOGGER.debug('### Found explicit error line: %s' % line.strip())
            user_err_msg += line.strip()
            error_on_previous_line = True

        # When R error messages are continued on another line, they may be
        # indented by two spaces.
        elif line.startswith("  ") and error_on_previous_line:
            #LOGGER.debug('### Found indented line following an error: %s' % line.strip())
            user_err_msg += " "+line.strip()
            error_on_previous_line = True

        # When R error messages end with a colon, they will be continued on
        # the next line, independently of their indentation I guess!
        elif colon_on_previous_line:
            #LOGGER.debug('### Found line following a colon: %s' % line.strip())
            user_err_msg += " "+line.strip()
            error_on_previous_line = True

        else:
            #LOGGER.debug('### Do not pass back to user: %s' % line.strip())
            error_on_previous_line = False

        # Remember whether this line ended with a colon, indicating that the
        # next line will continue with the error message:
        colon_on_previous_line = False
        if line.strip().endswith(":"):
            #LOGGER.debug('### Found a colon, next line will still be error!')
            colon_on_previous_line = True

    return user_err_msg
