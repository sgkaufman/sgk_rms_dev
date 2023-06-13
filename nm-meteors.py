#!/usr/bin/env python
import os
import sys
import traceback
import subprocess
import datetime
import logging
import argparse

from RMS.ConfigReader import loadConfigFromDirectory
from RMS.CaptureDuration import captureDuration
from RMS.Logger import initLogging
from daily_status_report import makeReport

def rmsExternal(captured_night_dir, archived_night_dir, config):
    initLogging(config, 'NM_Meteors_')
    log = logging.getLogger("logger")
    log.info('nm-meteors external script started')

    
    # create lock file to avoid RMS rebooting the system
    lockfile = os.path.join(config.data_dir, config.reboot_lock_file)
    with open(lockfile, 'w') as _:
        pass

    # Write the CaptureTimes.log file in /home/pi/RMS_data/logs
    captureDuration (config.latitude, config.longitude, config.elevation)

    # Compute the capture duration from now
    start_time, duration = captureDuration(config.latitude, \
                                           config.longitude, \
                                           config.elevation)

    
    timenow = datetime.datetime.utcnow()
    remaining_seconds = 0

    # Compute how long to wait before capture
    if start_time != True:
        waitingtime = start_time - timenow
        remaining_seconds = int(waitingtime.total_seconds())		

        # Run the nm-meteors.sh shell script
    script_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "nm-meteors.sh")
    log.info('Calling {}'.format(script_path))
    log.info('StationID: {}'.format(config.stationID))
    log.info('captured_night_dir: {}'.format(captured_night_dir))
    log.info('archived_night_dir: {}'.format(archived_night_dir))
    log.info('latitude: {}'.format(config.latitude))
    log.info('longitude: {}'.format(config.longitude))
    log.info('elevation: {}'.format(config.elevation))
    log.info('width: {}'.format(config.width))
    log.info('height: {}'.format(config.height))
    log.info('remaining_seconds: {}'.format(remaining_seconds))
    command = [
            script_path,
            config.stationID,
            captured_night_dir,
            archived_night_dir,
            '{:.6f}'.format(config.latitude),
            '{:.6f}'.format(config.longitude),
            '{:.1f}'.format(config.elevation),
            str(config.width),
            str(config.height),
            str(remaining_seconds)
            ]

    proc = subprocess.Popen(command,stdout=subprocess.PIPE)
   
    # Read iStream script output and append to log file
    while True:
        line = proc.stdout.readline()
        if not line:
            break
        log.info(line.rstrip().decode("utf-8"))

    exit_code = proc.wait()
    log.info('Exit status: {}'.format(exit_code))
    log.info('nm-meteors external script finished')

    # release lock file so RMS is authorized to reboot, if needed
    os.remove(lockfile)

    # The following will need to be uncommented when ExternalScript.py
    # is no longer run at the end of this Python file.
    # makeReport()
    
    # Reboot the computer (script needs sudo priviledges, works only on Linux)
    if (config.reboot_after_processing):
        try:
            log.info("Rebooting system...")
            os.system('sudo shutdown -r now')
        except Exception as e:
            log.debug('Rebooting failed with message:\n' + repr(e))
            log.debug(repr(traceback.format_exception(*sys.exc_info())))


####################################

if __name__ == "__main__":

    nmp = argparse.ArgumentParser(description="""Upload files to New_Mexico_Server, and optionally move other files to storage devices, create a TimeLapse.mp4 file, and reboot the system after all processing.""")

    nmp.add_argument('--archiveDir', type=str, \
                     help="Full path to archived data directory")
    nmp.add_argument('--captureDir', type=str, \
                     help="Full path to captured data directory")

    nmp.add_argument('--config', type=str, \
                     default="/home/pi/source/RMS", \
                     help="The full path to the directory containing the .config file for the camera.")

    args = nmp.parse_args()

    config = loadConfigFromDirectory('.', args.config)
    print ("Calling rmsExternal ...")
    rmsExternal(args.captureDir, args.archiveDir, config)
 
    # Create the config object for New Mexico Meteor Array purposes
    # nm_config = copy.copy(config)
    # nm_config.stationID = 'pi'
    # nm_config.hostname = '10.8.0.46'
    # nm_config.remote_dir = '/home/pi/RMS_Station_data'
    # nm_config.upload_queue_file = 'NM_FILES_TO_UPLOAD.inf'       
