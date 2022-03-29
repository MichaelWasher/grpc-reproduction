# gRPC / OVS packetloss reproduction

1. Download the ipctest tool and place in the base directory of the repo
1. Run `./scripts/setup.sh` to create all pre-requisite 
1. In another terminal, run `./scripts/collect.sh` to start collecting PCAPs
1. In another terminal, run `./scripts/stap.sh` to start collecting stap output
1. Run `./scripts/test.sh` to start the communications between Pods
1. Once finished, stop the collections with Ctrl + C and the output will be copied back to the workstation

Additional Notes:
The `./scripts/test.sh` purges the OVS kernel flows using `ovs-appctl revalidator/purge` before running the test between the two Pods. Both Pods are configured to be located on the same Node.
The `./scripts/test.sh` command accepts arguments which as passed to the ipctest tool

Example Usage:
```
⚡⇒ ./scripts/test.sh
No options provided. Using default options for ipctest: -l64 -n1000 -p60001 -4 -f m -v -L -u
##############################################################
Ensure that the IPC test tool is present at ./ipctest
##############################################################
Press ENTER to continue.
```
