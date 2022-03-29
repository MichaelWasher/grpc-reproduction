#!/bin/bash

# NOTE: There are sleeps in this to make sure that each application can finish starting before continuing. These may not be long enough and cause an issue, but just re-run this once the flow-rules have expired.

PACKET_COUNT=1000
DEFAULT_OPTIONS="-l64 -n${PACKET_COUNT} -p60001 -4 -f m -v -L -u "
# set -x


# Setup options
IPCTEST_OPTIONS="$@"

if [[ "$IPCTEST_OPTIONS" == "" ]]; then
    echo "No options provided. Using default options for ipctest: ${DEFAULT_OPTIONS}"
    IPCTEST_OPTIONS=${DEFAULT_OPTIONS}
else
    echo "Using provided options: ${IPCTEST_OPTIONS}"
fi

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

# Purge kernel rules
oc exec -t purge -- sh -c "chroot /host ovs-appctl revalidator/purge"

# Get Pod IPs
export POD_IP_SERVER=`oc get pods ipc-server -o jsonpath='{.status.podIP}'`

# Run the Test
oc exec -t ipc-server -- sh -c "/ipctest -r ${IPCTEST_OPTIONS} | tee server_logs" &

sleep 2
oc exec -t ipc-client -- sh -c "/ipctest -t ${IPCTEST_OPTIONS} ${POD_IP_SERVER} | tee client_logs" 

# Copy results back
oc cp ipc-server:/server_logs ./logs/server_logs
oc cp ipc-client:/client_logs ./logs/client_logs

