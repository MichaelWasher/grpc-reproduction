#!/bin/bash 

# A small application for configuring the tso and gso flags on the primary interfaces inside the Pods in Kubernetes
NODES=(<nodes>)
# i.e. NODES=(worker1 worker2)
for NODE in $NODES; do

    # Start the Debug Pods
    DEBUG_POD=`oc debug -o yaml node/${NODE} -- sleep inf | oc create -f - | grep "pod/" | cut -d " " -f 1 | cut -d "/" -f 2`

    # Get all Pods on Node
    NAMESPACE_PODS=`kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{";"}{.metadata.name}{";"}{.spec.hostNetwork}{"\n"}' --field-selector spec.nodeName=${NODE}`

    # Define function to run on Node
    function set_sysctl(){
        set -x
        # Enter NetNS
        NS=$1
        POD=$2
        pod_id=$(crictl pods --namespace ${NS} --name ${POD} -q)
        
        # NOTE; This is expected to fail in 4.9 and is recovered in the following if statement
        pid=$(bash -c "runc state $pod_id | jq .pid") || true

        if [ -z "$pid" ] ; then
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
        nsenter ${nsenter_parameters} -- ethtool -k eth0  | grep -e segmentation-off   
    }

    POD_SCRIPT=$(declare -f set_sysctl)

    # For all Pods
    for NS_POD in ${NAMESPACE_PODS}; do

        # Split tuple for POD + NS
        NAMESPACE=`echo ${NS_POD} | cut -d ";" -f 1`
        POD=`echo ${NS_POD} | cut -d ";" -f 2`
        
        # Skip pods in HostNetwork
        HOST_NET=`echo ${NS_POD} | cut -d ";" -f 3`
        if [[ "$HOST_NET" == "true" ]]; then
            continue
        fi

        # Set the Sysctl in Node for Pod
        oc exec -t "${DEBUG_POD}" -- chroot /host sh -c "$POD_SCRIPT; set_sysctl ${NAMESPACE} ${POD}"
    done
done

