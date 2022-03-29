#!/bin/bash

set -x
# Add Resources
oc apply -f ./manifests/ns.yaml

oc project 03073255
oc apply -f ./manifests/ipc-colocated-pods.yaml
oc apply -f ./manifests/collector-pod.yaml
oc apply -f ./manifests/purge-pod.yaml

# Wait for Pods to be ready
while [[ $(kubectl get pods -l app="ipc-client" -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for ipc-client pod" && sleep 1; done
while [[ $(kubectl get pods -l app="ipc-server" -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for ipc-server pod" && sleep 1; done

