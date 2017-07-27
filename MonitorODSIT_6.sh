#!/bin/bash
##  Key Bank failover script  #######################################
#
#   Version 6
#
#####################################################################

#####################################################################
# Set Variables
#
readonly FTS="SDC01TCMOAPP06"
readonly ODF="SDC01TCM0APP07"
readonly ARSBIN="/apps/IBM/ondemand/V9.5/bin"
readonly TSMBIN="/apps/IBM/tivoli/tsm/"
readonly ODFBIN="/apps/IBM/bin"
mkdir -p /apps/IBM/locks
readonly LOCK="/app/IBM/locks/CMODStart.lock"
mkdir -p /apps/IBM/logs
readonly LOGFILE="/app/IBM/logs/failover.log"
readonly USER="CMOSCHEM"
servers=(SDC01TCMOAPP02 SDC01TCMOAPP03)
#####################################################################


#####################################################################
### DEFINE FUNCTIONS ################################################
# Define function to check if arssockd is running, set tested machine
# to active if RC 0, set to standby if RC > 0

#FOR SIT ONLY
arsdocQuery() {
  arsdoc query -h $LOCAL -u Admin -p /apps/IBM/ondemand/V9.5/config/ars.stash -f "System Log" -H > dev/null
}

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

#Function to check TSM, start on Local if not running
startTSM() {
if [[ $(ps -ef | grep -c [d]smserv ) == 0 ]] 2>1; then
  "$TSMBIN"/dsmserv -quiet &
  sleep 1
    if [[ $? = 0 ]]; then
      echo "TSM Server started on "$1" at $(date)" >> $LOGFILE
      return 0
    else
      echo "TSM Server failed to start at $(date)" >> $LOGFILE
      # exit 1
    fi
  else
    echo "TSM Server running on "$LOCAL" at $(date)" >> $LOGFILE
    return 0
fi
}

# Function to start ODF
startODF() {
  SSH -qn "$USER"@${ODF} cd /
  if [[ $(ps -ef | grep -c [a]rsodf) == 0 ]]; then
    nohup "$ARSBIN"/arsodf -h "$1" -S &
    sleep 1
      if [[ $? = 0 ]]; then
        echo "ODF started on "$LOCAL" at $(date)" #>> $LOGFILE
      else
        echo "ODF failed to start at $(date)" #>> $LOGFILE
        # exit 1
      fi
  else
    echo "ODF  running on "$LOCAL" at $(date)" #>> $LOGFILE
  fi
}

# Function to start FTS Exporter
startFTSExporter() {
  if [[ $(ps -ef | grep -c [O]DFTIExporter)]]; then
    cd /apps/IBM/ondemand/V9.5/jars
    nohup java -Djava.library.path=/apps/IBM/ondemand/V9.5/lib64 -jar ODFTIExporter.jar index -configFile odfts.cfg &
    sleep 1
    if [[ $? = 0 ]]; then
      echo "FTS Exporter started on "$LOCAL" at $(date)" #>> $LOGFILE
    else
      echo "FTS Exporter failed to start at $(date)" #>> $LOGFILE
      # exit 1
    fi
  else
    echo "FTS Exporter running on "$LOCAL" at $(date)" #>> $LOGFILE
  fi
}
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
# determine activeServer
arsdocQuery "$LOCAL"
sleep 20
checkCMOD "$LOCAL"
checkCMOD "$REMOTE"
#for debugging can be removed
echo "Active is "$activeServer""
echo "Standby is "$standbyServer""

#Check activeServer to validate all services are running
if [[ "$LOCAL" == "$activeServer" ]]; then
#startTSM
startTSM
#startODF
startODF
#startFTSExporter
startFTSExporter
fi

# if no active server on either box start CMOD
if [[ -z "$activeServer" ]]
  # check for lock file on remote box
  checkLock $REMOTE
    if [[ $? -eq 0 ]]
    # create lockfile
    touch "$LOCK"
    # Start CMOD on Local server
    "$ARSBIN" arssockd -h "$LOCAL" -S
    sleep 1
	if [[ $? == 0 ]]; then
    activeServer="$LOCAL"
    echo "Active Server is $activeServer at $(date)"  #>> $LOGFILE
    echo "Starting other CMOD services"               #>> $LOGFILE
  #Start TSM, ODF, FTS
  startTSM
  startODF
  if [[ $? != 0 ]];then
    echo "ODF failed to start at $(date)" #>> $LOGFILE
  fi
  startFTSExporter
	#remove lockfile
    rm "$LOCK"
    fi
  fi
fi

sleep 300

done
