#!/bin/bash
##  Key Bank failover script  ####################
#
#   Version 3
#
##################################################


##################################################
# Set Variables
#
#Start OnDemand  "$(which arssockd)"
CMOD_BIN="/apps/IBM/ondemand/V9.5/bin"
#path to TSM  "$(which dsmsrv)"
TSM_BIN="/apps/IBM/tivoli/tsm"
LOCK="/app/IBM/locks/failover.lock"
##################################################
# Function to check for lockfile
checkLock() {
	if ssh -qn "$USER"@"$1" "[ -f "$LOCK" ]";then
	return 1
	else
	return 0
fi;
}

#Determine active/passive server

servers=(SDC01TCMOAPP02 SDC01TCMOAPP03)

# Determine Local and Remote Server
for server in "${servers[@]}"
do
if [[ ("$(hostname)" == "$server") ]]; then
  readonly LOCAL="$server"
if [[ ("$(hostname)") != "$server" ]]; then
  readonly REMOTE="$server"
done


#check for lockfile
checkLock()
	echo "Lock prevented Script from running on $(activeCMOD) at $(date)" >> /app/IBM/logs/Failover.log &
	exit 1
else
	echo "Script ran on $(activeCMOD) at $(date)" >> /app/IBM/logs/Failover.log &

fi
#create lock file;
touch "$LOCK"


set -m

# Launch CMOD & TSM on trap with KILL on fail
trap 'list=$( jobs -rp ); test -n "$list" && kill $list' CHLD

# Start OnDemand
"$CMOD_BIN" arssockd -h "$LOCAL" &

# Start Tivoli
"$TSM_BIN" dsmserv -quiet &

wait

# Failover
	echo "CMOD Failover to $(standybyCMOD) on $(date)" >> /app/IBM/logs/Failover.log
	SSH CMOSCHEM@${standbyCMOD} /app/IBM/scripts/MonitorODSIT_3.sh
	echo "ARSSOCKD required a restart on $(activeCMOD) at $(date)" >> /app/IBM/logs/Failover.log
	exit (1)

#remove lockfile
rm $LOCK
