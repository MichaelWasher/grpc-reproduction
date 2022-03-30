#!/bin/bash

NODE=$1
set -ex

# A small application for configuring the tso and gso flags on the primary interfaces inside the Pods on a Node in Kubernetes
if [[ "${NODE}" == "" ]]; then
    echo "Please specify a Node when calling the configuration script."
    echo "$0 <node-name>"
    exit 1
else
    echo "Node '$NODE' was provided to have GSO/TSO to be disabled. Please ensure this is correct before continuing."
    echo "Also; This script has only been tested on OpenShift 4.9.23. Please ensure that this version is correct"
    read -p "Press ENTER to continue."
fi

# Basic check on Node is valid
oc get nodes -o name ${NODE}

# Delete old Debug Pod
oc debug node/${NODE} --dry-run=client -o name | xargs -n 1 oc delete || true
while [[ $(kubectl get pods ${DEBUG_POD} -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') == "True" ]]; do echo "waiting for debug pod removal" && sleep 3; done

# Start the debug Pod and wait to be running
DEBUG_POD=$(oc debug -o yaml --dry-run=client node/${NODE} -- sleep inf | oc create -f - | grep "pod/" | cut -d " " -f 1 | cut -d "/" -f 2)
while [[ $(kubectl get pods ${DEBUG_POD} -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for debug pod to start" && sleep 3; done

# Get all Pods on Node
NAMESPACE_PODS=$(kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{";"}{.metadata.name}{";"}{.spec.hostNetwork}{"\n"}{end}' --field-selector spec.nodeName=${NODE},status.phase=Running)

# Define function to run on Node
function set_values_in_pod() {
    set -x
    # Enter NetNS
    NS=$1
    POD=$2
    pod_id=$(crictl pods --namespace ${NS} --name ${POD} -q)

    # NOTE; This is expected to fail in 4.9 and is recovered in the following if statement
    pid=$(bash -c "runc state $pod_id | jq .pid") || true

    if [ -z "$pid" ]; then
        # Check in OpenShift 4.9 to
        ns_path=$(crictl inspectp $pod_id | jq -r '.info.runtimeSpec.linux.namespaces[]|select(.type=="network").path')
        nsenter_parameters="--net=${ns_path}"
    else
        nsenter_parameters="-n -t $pid"
    fi

    # Perform the Sysctl changes here
    nsenter ${nsenter_parameters} -- ethtool -K eth0 tso off
    nsenter ${nsenter_parameters} -- ethtool -K eth0 gso off

    # List changes
    nsenter ${nsenter_parameters} -- ethtool -k eth0 | grep -e segmentation-off
}

POD_SCRIPT=$(declare -f set_values_in_pod)

# For all Pods
for NS_POD in ${NAMESPACE_PODS}; do

    # Split tuple for POD + NS
    NAMESPACE=$(echo ${NS_POD} | cut -d ";" -f 1)
    POD=$(echo ${NS_POD} | cut -d ";" -f 2)

    # Skip pods in HostNetwork
    HOST_NET=$(echo ${NS_POD} | cut -d ";" -f 3)
    if [[ "$HOST_NET" == "true" ]]; then
        continue
    fi

    # Set the Sysctl in Node for Pod
    oc exec -t "${DEBUG_POD}" -- chroot /host sh -c "$POD_SCRIPT; set_values_in_pod ${NAMESPACE} ${POD}"
done

# Set for all NICs in default NetNS
function set_values_on_node() {
    for NIC in $(ip -o link show up | cut -d : -f 2 | cut -d "@" -f 1); do
        echo $NIC
        ethtool -k $NIC | grep "segmentation-off"
        ethtool -K $NIC tso off
        ethtool -K $NIC gso off
    done
}

NDOE_SCRIPT=$(declare -f set_values_on_node)
oc exec -t "${DEBUG_POD}" -- chroot /host sh -c "${NDOE_SCRIPT}; set_values_on_node"

## Output complete
echo "##########################################"
echo "GSO and TSO are off for all interfaces on ${NODE}"
echo "##########################################"