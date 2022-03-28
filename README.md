# gRPC / OVS packetloss reproduction

1. Download the ipctest tool and place in the base directory of the repo
1. Run `./scripts/setup.sh` to create all pre-requisite 
1. In another terminal, run `./scripts/collect.sh` to start collecting PCAPs
1. In another terminal, run `./scripts/stap.sh` to start collecting stap output
1. Run `./scripts/test.sh` to start the communications between Pods
1. Once finished, stop the collections with Ctrl + C and the output will be copied back to the workstation

