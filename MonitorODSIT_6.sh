#!/bin/bash
##  Key Bank failover script  #######################################
#
#   Version 6
#
#####################################################################

#####################################################################
# Set Variables
#
ARSBIN="/apps/IBM/ondemand/V9.5/bin"
TSMBIN="/apps/IBM/tivoli/tsm/"
LOCK="/app/IBM/locks/CMODStart.lock"
LOGFILE="/app/IBM/logs/failover.log"
USER="CMOSCHEM"
servers=(SDC01TCMOAPP02 SDC01TCMOAPP03)
#####################################################################


#####################################################################
### DEFINE FUNCTIONS ################################################
# Define function to check if arssockd is running, set tested machine
# to active if RC 0, set to standby if RC > 0
checkCMOD() {
  arssockd -h $1 -P 2>1
  if [[ $? -eq 0 ]]; then
    activeServer=$1
    return 0
  elif [[ $? -gt 0 ]]; then
    standbyServer=$1
    return 2
fi;
}

# Function to check for lockfile
checkLock() {
	if ssh -qn "$USER"@"$1" "[ -f "$LOCK" ]";then
	return 1
	else
	return 0
fi;
}
# Function to start ODF

# Function to start FTS

# END OF FUNCTION LIST ##############################################
#####################################################################

# Determine Local and Remote Server
for server in "${servers[@]}"
do
if [[ ("$(hostname)" == "$server") ]]; then
  readonly LOCAL="$server"
if [[ ("$(hostname)") != "$server" ]]; then
  readonly REMOTE="$server"
done


#####################################################################
## MAIN ##
# Check CMOD on both boxes, function will set activeServer and
# standbyServer It will result in no activeServer value if both are
# not running arssockd

while (true)
do
# Set activeServer to empty
activeServer=""

checkCMOD "$LOCAL"
checkCMOD "$REMOTE"
#for debugging can be removed
echo "Active is "$activeServer""
echo "Standby is "$standbyServer""

#Check activeServer to validate all services are running


# if no active server on either box start CMOD
if [[ -z "$activeServer" ]]
  # check for lock file on remote box
  checkLock $REMOTE
    if [[ $? -eq 0 ]]
    # create lockfile
    touch "$LOCK"
    # Start CMOD on Local server
    "$ARSBIN" arssockd -h "$LOCAL" -S
	if [[ $? == 0 ]]; then
    activeServer="$LOCAL"
    echo "Active Server is $activeServer at $(date)"  #>> $LOGFILE
    echo "Starting other CMOD services"               #>> $LOGFILE
	#Start TSM, ODF, FTS
	#remove lockfile
    rm "$LOCK"
    fi
  fi
fi

sleep 300

done
