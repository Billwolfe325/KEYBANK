#!/bin/bash
##  Key Bank failover script  ####################
#
#   Version 5
#
##################################################

##################################################
# Set Variables
#
ARSBIN="/apps/IBM/ondemand/V9.5/bin"
TSMBIN="/apps/IBM/tivoli/tsm/"
LOCK="/app/IBM/locks/CMODStart.lock"
LOGFILE="/app/IBM/logs/failover.log"
USER="CMOSCHEM"
servers=(SDC01TCMOAPP02 SDC01TCMOAPP03)
##################################################



### Define functions ###
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
# function check for lockfile
checkLock() {
	if ssh -qn "$USER"@"$1" "[ -f "$LOCK" ]";then
	return 1
	else
	return 0
fi;
}

# Determine Local and Remote Server
for server in "${servers[@]}"
do
if [[ ("$(hostname)" == "$server") ]]; then
  readonly LOCAL="$server"
if [[ ("$(hostname)") != "$server" ]]; then
  readonly REMOTE="$server"
done


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
    #remove lockfile
    rm "$LOCK"
    fi
  fi
fi

############################################################
# For Mags
## Is above all that is needed ??
# Logic:
#
# Script starts-
#   -sets Local and remote as readonly variables
#
#   -checks CMOD on Local box
#      -if CMOD running sets local as activeServer
#      -if CMOD not running sets local as standbyServer
#   -checks CMOD on remote box
#      -if CMOD running sets remote as active
#      -if CMOD not running sets remote as standby
#   - if both tests above give rc > 0 activeServer
#     would not have been set so check for lock on remote
#      if no lock start CMOD if starts remove lock,
#      if remote is locked, local is already set as standby
#
############################################################
# If not here is the rest


checkCMOD $LOCAL
if [[ $? -gt 0 ]]; then
  checkLock $REMOTE
  # Lock file exists
  if [[ $? -eq 1 ]]; then
    checkCMOD $REMOTE
      if [[ $? -eq 0 ]]; then
      # Remote server is active so sleep until next check, checkCMOD $LOCAL
      #  function labeled local as standBy
      sleep 300
# no lock on remote
  elif [[ $? -gt 0 ]]; then
    checkCMOD $REMOTE
    if [[ $? -gt 0 ]]; then
      # create lock file
      touch "$LOCK"
      # Start CMOD on Local server
      "$ARSBIN" arssockd -h "$LOCAL" -S
      if [[ $? == 0 ]]; then
        activeServer="$LOCAL"
        echo "Active Server is $activeServer at $(date)"  #>> $LOGFILE
        #remove lockfile
        rm "$LOCK"
      fi
    fi
  fi
fi
sleep 300

done
