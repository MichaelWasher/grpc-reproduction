#!/bin/bash

# Ensure collector pod present
oc project 03073255
oc adm policy add-cluster-role-to-user cluster-admin -z default 
oc apply -f ./manifests/collector-pod.yaml -f ./manifests/stap-pod.yaml

debug_pod=collector

# Keepalive is to avoid stale/timout issues with `oc debug/exec` requests
keepalive() {
    while true; do
        sleep 1
        echo -n .
    done
}
# Triger PCAP in Pod
pcap_outer(){
    keepalive &
    mkdir -p /host/tmp/collect/
    pod_name=$1
    cont_id=`oc get pods -o json ${pod_name} | jq -r '.status.containerStatuses[0].containerID' | cut -d '/' -f 3`
    pid=`chroot /host crictl inspect --output json $cont_id | jq .info.pid`
    ifindex=$(nsenter -t $pid -n ip link | sed -n -e 's/.*eth0@if\([0-9]*\):.*/\1/p')
    veth=`ip -o link | grep ^$ifindex | cut -d ":" -f 2 | cut -d "@" -f 1`
    tcpdump -i $veth -w /host/tmp/collect/${pod_name}-outer.pcap
}

pcap_any(){
    keepalive &
    mkdir -p /host/tmp/collect/
    tcpdump -i any -w /host/tmp/collect/any.pcap
}

pcap_inner(){
    keepalive &
    mkdir -p /host/tmp/collect/
    pod_name=$1
    cont_id=`oc get pods -o json $1 | jq -r '.status.containerStatuses[0].containerID' | cut -d '/' -f 3`
    pid=`chroot /host crictl inspect --output json $cont_id | jq .info.pid`
    nsenter -n -t $pid -- tcpdump -i any -w /host/tmp/collect/${pod_name}.pcap
}

conntrack_events(){
    keepalive &
    mkdir -p /host/tmp/collect/
    chroot /host conntrack -E -o extended,timestamp 2>&1 > /host/tmp/collect/conntrack-events.txt
}

term() {
    echo "Completed TCPDump"
    pkill -P $$
    
    oc exec -t "${debug_pod}" -- sh -c "killall tcpdump conntrack" 
    # Collect PCAPs
    echo "Collecting PCAPs"
    oc cp  ${debug_pod}:/host/tmp/collect/ ./collect
}
trap term SIGTERM SIGINT


pod_script=$(declare -f keepalive pcap_any pcap_outer pcap_inner conntrack_events)

echo "----------------------------------------------------------"
echo "Starting the pcaps. These will run until failure of killed. Kill with Crtl + C to copy back the contents"
echo "----------------------------------------------------------"

oc exec -t "${debug_pod}" -- sh -c "$pod_script; conntrack_events" &
# oc exec -t "${debug_pod}" -- sh -c "$pod_script; pcap_any" &

oc exec -t "${debug_pod}" -- sh -c "$pod_script; pcap_outer ipc-server" &
oc exec -t "${debug_pod}" -- sh -c "$pod_script; pcap_outer ipc-client" &

oc exec -t "${debug_pod}" -- sh -c "$pod_script; pcap_inner ipc-server" &
oc exec -t "${debug_pod}" -- sh -c "$pod_script; pcap_inner ipc-client" 

