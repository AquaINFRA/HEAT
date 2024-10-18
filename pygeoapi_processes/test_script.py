import requests
import time
import sys

'''
This is just a little script to test whether the OGC processing
services of the AquaINFRA project HELCOM HEAT use case were properly
installed using pygeoapi and run as expected.
This does not test any edge cases, just a very basic setup. The input
data may already be on the server, so proper downloading is not 
guaranteed.

Check the repository here:
https://github.com/ices-tools-prod/HEAT

AquaINFRA fork with pygeoapi processes:
https://github.com/AquaINFRA/HEAT


Merret Buurman (IGB Berlin), 2024-08-15
'''


base_url = 'https://xxx.xxx/pygeoapi'

headers_sync = {'Content-Type': 'application/json'}
headers_async = {'Content-Type': 'application/json', 'Prefer': 'respond-async'}


# Get started...
session = requests.Session()

force_async = False

# Define helper for polling for asynchronous results
def poll_for_json_result(resp201, session, seconds_polling=2, max_seconds=60*60):
    link_to_result = poll_for_links(resp201, session, 'application/json', seconds_polling, max_seconds)
    result_application_json = session.get(link_to_result)
    #print('The result JSON document: %s' % result_application_json.json())
    return result_application_json.json()

def poll_for_links(resp201, session, required_type='application/json', seconds_polling=2, max_seconds=60*60):
    # Returns link to result in required_type
    
    if not resp201.status_code == 201:
        print('This should return HTTP status 201, but we got: %s' % resp201.status_code)
    
    print('Where to poll for status: %s' % resp201.headers['location'])
    print('Polling every %s seconds...' % seconds_polling)
    seconds_passed = 0
    polling_url = resp201.headers['location']
    while True:
        polling_result = session.get(resp201.headers['location'])
        job_status = polling_result.json()['status'].lower()
        print('Job status: %s' % job_status)
        
        if job_status == 'accepted' or job_status == 'running':
            if seconds_passed >= max_seconds:
                print('Polled for %s seconds, giving up...' % max_seconds)
            else:
                time.sleep(seconds_polling)
                seconds_passed += seconds_polling

        elif job_status == 'failed':
            print('Job failed after %s seconds!' % seconds_passed)
            print('Debug info: %s' % polling_result.json())
            print('Stopping due to failure.')
            sys.exit(1)

        elif job_status == 'successful':
            print('Job successful after %s seconds!' % seconds_passed)
            links_to_results = polling_result.json()['links']
            #print('Links to results: %s' % links_to_results)
            print('Picking the "%s"-type link from %s links to results.' % (required_type, len(links_to_results)))
            link_types = []
            for link in links_to_results:
                link_types.append(link['type'])
                if link['type'] == required_type:
                    #print('We pick this one (type %s): %s' % (required_type, link['href']))
                    link_to_result = link['href']
                    return link_to_result

            print('Did not find a link of type "%s"! Only: %s' % (required_type, link_types))
            print('Stopping due to failure.')
            sys.exit(1)

        else:
            print('Could not understand job status: %s' % polling_result.json()['status'].lower())
            print('Stopping due to failure.')
            sys.exit(1)

def check_one_process(url, inputs, name_of_main_output):

    url = base_url+'/processes/%s/execution' % name

    # sync:
    print('synchronous...')
    resp = session.post(url, headers=headers_sync, json=inputs)
    print('Calling %s... done. HTTP %s' % (name, resp.status_code)) # should be HTTP 200
    if resp.status_code == 200:
        result_application_json = resp.json()
        print('  Result (JSON document): %s' % result_application_json)

    # or async:
    if not resp.status_code == 200 or force_async:
        print('asynchronous...')
        resp = session.post(url, headers=headers_async, json=inputs)
        print('Calling %s... done. HTTP %s' % (name, resp.status_code)) # should be HTTP 201
        result_application_json = poll_for_json_result(resp, session)
        print('  Result (JSON document): %s' % result_application_json)

    # Results (sync / async, does not matter):
    href = result_application_json['outputs'][name_of_main_output]['href']
    print('  It contains a link to our ACTUAL result: %s' % href)
    # Check out result itself:
    final_result = session.get(href)
    print('  Result content: %s...' % str(final_result.content)[0:200])
    return href


assessment_period = "HOLAS-3" #"2016-2021"
#assessment_period = "HOLAS-2" #"2011-2016"
#assessment_period = "Other" #"1877-9999"

##############
### heat_1 ###
##############

name = "heat_1"
print('\nCalling %s...' % name)
inputs = { 
    "inputs": {
        "assessment_period": assessment_period
    }
}

resultlink_heat1 = check_one_process(name, inputs, 'units_gridded')



##############
### heat_2 ###
### using HELCOM inputs ###
##############
name = "heat_2"
print('\nCalling %s...' % name)
inputs = { 
    "inputs": {
        "assessment_period": assessment_period
    }
}

resultlink_heat2 = check_one_process(name, inputs, 'samples')

#print('Stopping here...')
#sys.exit()


##############
### heat_3 ###
### using HELCOM inputs ###
##############
name = "heat_3"
print('\nCalling %s...' % name)
inputs = { 
    "inputs": {
        "assessment_period": assessment_period,
        "combined_Chlorophylla_IsWeighted": True,
        "samples": resultlink_heat2
    }
}
resultlink_heat3 = check_one_process(name, inputs, 'annual_indicators')

##############
### heat_4 ###
### using HELCOM inputs ###
##############
name = "heat_4"
print('\nCalling %s...' % name)
inputs = { 
    "inputs": {
        "assessment_period": assessment_period,
        "annual_indicators": resultlink_heat3
    }
}
resultlink_heat4 = check_one_process(name, inputs, 'assessment_indicators')

##############
### heat_5 ###
### using HELCOM inputs ###
##############
name = "heat_5"
print('\nCalling %s...' % name)
inputs = { 
    "inputs": {
        "assessment_period": assessment_period,
        "assessment_indicators": resultlink_heat4
    }
}
resultlink_heat5 = check_one_process(name, inputs, 'assessment')


###################
### Finally ... ###
###################
print('Done!')

