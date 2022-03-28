#!/bin/bash
set -x

oc rsh ipc-client killall ipctest
oc rsh ipc-server killall ipctest
