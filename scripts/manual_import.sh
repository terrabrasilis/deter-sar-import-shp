#!/bin/bash
# set env vars to use inside script
source /etc/environment
cd $INSTALL_PATH/scripts-shell

echo "DETER_R_AMZ_CR2_2021-04-27_2021-04-27.zip" > "$INPUT_DIR/trigger.txt"
. ./import_shapes_to_database.sh
