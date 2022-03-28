#!/bin/bash

# Ensure collector pod present
oc project 03073255
oc adm policy add-cluster-role-to-user cluster-admin -z default 
oc apply -f ./manifests/stap-pod.yaml

debug_pod="stap"

# Keepalive is to avoid stale/timout issues with `oc debug/exec` requests
keepalive() {
    while true; do
        sleep 1
        echo -n .
    done
}

run_stap(){
    keepalive &
    mkdir -p /host/tmp/stap_collect/
    stap -g stap.stp > /host/tmp/stap_collect/stap.txt
}


term() {
    echo "Completed Stap"
    pkill -P $$
    
    # oc exec -t "${debug_pod}" -- sh -c "killall stap"
    
    # Collect output
    echo "Collecting stap output"
    oc cp  ${debug_pod}:/host/tmp/stap_collect/stap.txt ./stap_collect/stap.txt
}
trap term SIGTERM SIGINT

while [[ $(kubectl get pods -l app="stap" -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for stap pod" && sleep 1; done

pod_script=$(declare -f keepalive run_stap)


echo "----------------------------------------------------------"
echo "Starting the stap script. These will run until failure of killed. Kill with Crtl + C to copy back the contents"
echo "----------------------------------------------------------"

oc cp ./scripts/skbuff.stp "${debug_pod}":/st   ap.stp
oc exec -t "${debug_pod}" -- sh -c "$pod_script; run_stap" 
