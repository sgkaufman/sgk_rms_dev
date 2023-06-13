#!/bin/bash

# lots of borrowed code from IstraStream here, Thanks, IstraStream!
# For stations that also upload IstraStream, we assume that
# ~/source/RMS/iStream.sh has already executed and created the
# files *captured.bmp and the TimeLapse.mp4.

# Our version of iStream.sh
echo ""
echo "START EXTERNAL SCRIPT..." 
echo ""
echo "CHECKING ARGUMENTS..."
echo ""

# Arguments are:
# 1. stationID
# 2. captured_night_dir
# 3. archived_night_dir
# 4. latitude (6 point precision)
# 5. longitude (6 point precision)
# 6. elevation (6 point precision)
# 7. camera FOV width (degrees)
# 8. camera FOV height (degrees)
# 9. remaining seconds

if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" || -z "$6" || -z "$7" || -z "$8" || -z "$9" ]]; then
	echo "MISSING ARGUMENTS - (SHOULD BE 9)"
	echo "EXIT..."
	echo ""	
	exit
fi

STATION_ID=$1; printf "Station ID: %s\n" $STATION_ID
CAPTURED_DIR_NAME=$2; printf "CAPTURED_DIR_NAME: %s\n" $CAPTURED_DIR_NAME
ARCHIVED_DIR_NAME=$3; printf "ARCHIVED_DIR_NAME: %s\n" $ARCHIVED_DIR_NAME
LATITUDE=$4; printf "LATITUDE: %s\n" $LATITUDE
LONGITUDE=$5; printf "LONGITUDE: %s\n" $LONGITUDE
ELEVATION=$6; printf "ELEVATION: %s\n" $ELEVATION
WIDTH=$7; printf "WIDTH: %s\n" $WIDTH
HEIGHT=$8; printf "HEIGHT: %s\n" $HEIGHT
REMAINING_SECONDS=$9; printf "REMAINING_SECONDS: %s\n" $REMAINING_SECONDS

SYSTEM="rms"
SERVER="https://nm-meteors.net/test-upload-swcp.php"
AGENT="$SYSTEM-$STATION_ID"

CapStack=1
iStream=0


# Sanity checks
if [[ ! -d $ARCHIVED_DIR_NAME ]] ; then
    echo "ArchivedFiles Directory does not exist! Exiting ..."
    exit 1
fi

if [[ ! -d $CAPTURED_DIR_NAME ]] ; then
    echo "CapturedFiles Directory does not exist! Exiting ..."
    exit 1
fi

# End Sanity Checks

# Get meteor count

FTP_DETECT_INFO="$(find $CAPTURED_DIR_NAME -name '*.txt' | grep 'FTPdetectinfo' | grep -vE 'uncalibrated' | grep -vE 'unfiltered')"

#Thanks to Alfredo Dal'Ava Junior :)
if [[ -z "$FTP_DETECT_INFO" ]]; then
   METEOR_COUNT="0"
else
   METEOR_COUNT="$(sed -n 1p $FTP_DETECT_INFO | awk '{ print $NF }')"
fi

## Set up capture video filenames
DATE_NOW=$(date +"%Y%m%d")
TMP_VIDEO_FILE="$CAPTURED_DIR_NAME/$(basename $CAPTURED_DIR_NAME).mp4"
VIDEO_FILE="$CAPTURED_DIR_NAME/${STATION_ID}_${DATE_NOW}.mp4"

###################### Function Definitions ##########################

function generate_timelapse {
    cd ~/source/RMS
    python -m Utils.GenerateTimelapse $CAPTURED_DIR_NAME
    mv $TMP_VIDEO_FILE $VIDEO_FILE
}

###########################################################

# Stacks are created using the Utils.StackFFs python module.
# Its stack names always end with "_stack_nnn_meteors", and the
# file type can be specified. iStream creates the big, all FF files
# in the CapaturedFile directory as a .bmp file. It needs to be renamed
# to "...stack_nnn_captured" in the ArchivedFiles directory.
# Look for a bmp stack of the capture directory. iStream may have created it.
# Convert it to a jpg if it there; create it if it isn't.
# Conversion is quickly done using the command "convert-im6.q16".

# RMS makes the '...stack_nnn_meteors.jpg' file
# (in Reprocess.py, when it calls archiveDetections)

## The following files should be uploaded:
## detection stack (stack_nn_meteors.jpg),
## capture stack   (stack_nnnn_captured.jpg),
## astrometry      (calib_report_astrometry.jpg),
## photometry      (calib_report_photometry.png),
## FTPdetectinfo_US000N_20230227_012348_292483.txt
## US000N_20230227_012348_292483_calibration_variation.png
## US000N_20230227_012348_292483_CAPTURED_thumbs.jpg
## US000N_20230227_012348_292483.csv
## US000N_20230227_012348_292483_DETECTED_thumbs.jpg
## US000N_20230227_012348_292483_fieldsums_noavg.png
## US000N_20230227_012348_292483_fieldsums.png
## US000N_20230227_012348_292483_observing_periods.png
## US000N_20230227_012348_292483_photometry_variation.png
## US000N_20230227_012348_292483_radiants.png
## US000N_20230227_012348_292483_radiants.txt
## US000N_20230227_012348_292483_stack_29_meteors.jpg

############# Upload Files ################################
file=$(find $ARCHIVED_DIR_NAME -name '*stack*meteors.jpg') 
if [[ -f $file ]] ; then
   echo "Uploading detection stack"
   curl -F "type=IMAGE" -F "date_str=""$DATE_NOW" -F "upload=@""$file"  "$SERVER"
else
    echo "No detection stack found"
fi

file=$(find $ARCHIVED_DIR_NAME -name '*captured_stack.jpg') 
if [[ -f $file ]] ; then
   echo "Uploading capture stack"
   curl -F "type=IMAGE" -F "date_str=""$DATE_NOW" -F "upload=@""$file"  "$SERVER"
else
   echo "No capture stack found"
fi

file=$(find $ARCHIVED_DIR_NAME -name '*calib_report_astrometry.jpg') 
if [[ -f $file ]] ; then
    echo "Uploading astrometry calibration"
    curl -F "type=IMAGE" -F "date_str=""$DATE_NOW" -F "upload=@""$file"  "$SERVER"
else
    echo "No astrometry calibration file found"
fi

file=$(find $ARCHIVED_DIR_NAME -name '*calib_report_photometry.png') 
if [[ -f $file ]] ; then
    echo "Uploading photometry calibration"
    curl -F "type=IMAGE" -F "date_str=""$DATE_NOW" -F "upload=@""$file" "$SERVER"
else
    echo "No photometry file found"
fi
#################################################################
generate_timelapse

/home/pi/source/NMMA/RMS_extra_tools/Check_and_Clean.sh $CAPTURED_DIR_NAME
#/home/pi/source/NMMA/ErrorCheck.sh $ARCHIVED_DIR_NAME

#################################################################
#
# Call ExternalScript.py; Get the environment for the Python call set up,
# and move to the right directory
source "$HOME"/vRMS/bin/activate
cd "$HOME"/source/NMMA
python -m ExternalScript --directory $ARCHIVED_DIR_NAME \
       --reboot 1


################################################################
#
# Still to do:
# Copy the radiants.txt file up to the RMS_data/csv directory.
# If My_Uploads=1, remove all files from ~/RMS_data/My_Uploads.
# If My_Uploads=1, copy TimeLapse mp4 file to ~/RMS_data/My_Uploads.
# If My_Uploads=1, copy CaptureStack jpg file to ~/RMS_data/My_Uploads.
# If My_Uploads=1, copy Radiants.jpg to ~/RMS_data/My_Uploads.
# If My_Uploads=1, copy detected stack to ~/RMS_data/ My_Uploads
# 1. Create fits count file if it doesn't already exist; get file handle
# 2. Compare capture time to number of .fits files
# 3. Count the number of directories under CapturedFiles and ArchivedFiles
#    directories with the night's name, and write them out to the
#    file in the csv directory
# 4. Count the total number of captured directories;
#    if only one, write out the free space and total space to csv file.
# 5. (in ExternalScript.py) Call BackupToUSB.sh if it exists
# 6. (in ExternalScript.py) Call My_Uploads.sh

# Diagnostics: 0, 1, 2, 3, 4
# Other file movements: un-numbered actions at top, 5, 6
#################################################################
#
# Upload to NM Server and reboot
#

#if [[ ${My_Uploads} = 1 ]]; then
#    printf 'Cleaning out older files in My_Uploads\n'
#    rm "$HOME"/RMS_data/My_Uploads/*
#fi

#if [[ ${My_Uploads} = 1 ]]; then
#    printf 'Copying Radiants.jpg to My_Uploads\n'
#    cp ./*radiants.png "$HOME"/RMS_data/My_Uploads/Radiants.png
#fi

