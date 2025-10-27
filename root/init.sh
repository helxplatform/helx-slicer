#!/bin/bash

set -eoux pipefail

# The USER variable will be set if this container is created with Tycho, on
# most (if not all) local environments USER will also be set.  If USER is not

if [ -z "${USER+x}" ]; then
  echo "USER is not set, setting it to helx"
  USER=helx
fi

export USER=${USER-"jovyan"}
export DEFAULT_USER="jovyan"
export HOME="/home/$USER"

# Change to the root directory to mitigate problems if the current working
# directory is deleted.
cd /

# Add other init scripts in $HELX_SCRIPTS_DIR with ".sh" as their extension.
# To run in a certain order, name them appropriately.
HELX_SCRIPT_DIR=/helx-startup
INIT_SCRIPTS_TO_RUN=$(ls -1 $HELX_SCRIPT_DIR/*.sh) || true
for INIT_SCRIPT in $INIT_SCRIPTS_TO_RUN
do
  echo "Running $INIT_SCRIPT"
  $INIT_SCRIPT  
done

# Change CWD to /home/$USER so it is the starting point for shells in jupyter.
cd $HOME