#!/bin/bash

# NOTE: There are sleeps in this to make sure that each application can finish starting before continuing. These may not be long enough and cause an issue, but just re-run this once the flow-rules have expired.

set -x

term() {
    echo "Cancelling test..."
    pkill -P $$
    
    source ./scripts/kill.sh

    # Copy results back
    oc cp ipc-server:/server_logs server_logs
    oc cp ipc-client:/client_logs client_logs

    exit 1
}

# Confirm that the testing tool is present
echo "##############################################################"
echo "Ensure that the IPC test tool is present at ./ipctest"
echo "##############################################################"
read -p "Press ENTER to continue."

trap term SIGTERM SIGINT

# Ensure not running so sockets can be captured
source ./scripts/kill.sh

# Add Resources
# source ./setup.sh

# Copy files into Pods
oc cp ./ipctest ipc-client:/ipctest
oc cp ./ipctest ipc-server:/ipctest

# Get Pod IPs
export POD_IP_SERVER=`oc get pods ipc-server -o jsonpath='{.status.podIP}'`

# Run the Test
oc exec -t ipc-server -- sh -c "/ipctest -r -l64 -n10 -p60001 -4 -f m -v -u -L | tee server_logs" &
sleep 2
oc exec -t ipc-client -- sh -c "/ipctest -t -l64 -n10 -p60001 ${POD_IP_SERVER} -f m -v -u -L | tee client_logs" 

# Copy results back
oc cp ipc-server:/server_logs ./logs/server_logs
oc cp ipc-client:/client_logs ./logs/client_logs

