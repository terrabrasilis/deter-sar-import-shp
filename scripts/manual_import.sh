#!/bin/bash
# set env vars to use inside script
source /etc/environment
cd $INSTALL_PATH/scripts-shell

echo "deter_r_29_04_21.json" > "$INPUT_DIR/trigger.txt"
. ./import_to_database.sh
