#!/bin/bash
# set env vars to use inside script
source /etc/environment
cd $INSTALL_PATH/scripts-shell

# disable sendmail
export EMAIL_CTRL=false

# disable cron script
chmod -x $INSTALL_PATH/exec_cron.sh

echo "DETER_R_AMZ_CR2_2023-01-24_2023-01-24.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2023-01-25"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2023-01-25_2023-01-25.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2023-01-26"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2023-01-26_2023-01-26.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2023-01-27"
. ./import_to_database.sh

# enable cron script
chmod +x $INSTALL_PATH/exec_cron.sh