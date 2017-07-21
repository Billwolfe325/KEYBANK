#!/bin/bash 
##  Key Bank failover script  ####################
#
#   Version 3
#
##################################################


##################################################
# Set Variables
#
# Instance of OnDemand
INSTANCE="CMOSIT"
#
#Start OnDemand  "$(which arssockd)"
CMOD_BIN="/apps/IBM/ondemand/V9.5/bin"
#path to TSM  "$(which dsmsrv)"
TSM_BIN="/apps/IBM/tivoli/tsm"
LOCK="/app/IBM/locks/failover.lock"
##################################################


#Determine active/passive server

servers=(SDC01TCMOAPP02 SDC01TCMOAPP03)

if [[ ("$(hostname)" == ${servers[0]}) ]]; then
    activeCMOD=${servers[0]}
	standybyCMOD=${servers[1]}
fi

if [[ ("$(hostname)" == ${servers[1]}) ]]; then
	activeCMOD=${servers[1]}
	standybyCMOD=${servers[0]}
fi


#check for lockfile
if [ -f "$LOCK" ]; then
	echo "Lock prevented Script from running on $(activeCMOD) at $(date)" >> /app/IBM/logs/Failover.log &
	exit 1
else
	echo "No lock, Script ran on $(activeCMOD) at $(date)" >> /app/IBM/logs/Failover.log &

fi
#create lock file;
touch "$LOCK"


set -m

# Launch CMOD & TSM on trap with KILL on fail
trap 'list=$( jobs -rp ); test -n "$list" && kill $list' CHLD

# Start OnDemand
"$CMOD_BIN" arssockd -I "$INSTANCE" &

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
