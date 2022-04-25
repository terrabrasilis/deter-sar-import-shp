#!/bin/bash
# set env vars to use inside script
source /etc/environment
cd $INSTALL_PATH/scripts-shell

# disable sendmail
export EMAIL_CTRL=false

echo "DETER_R_AMZ_CR2_2022-04-04_2022-04-04.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2022-04-05"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2022-04-05_2022-04-05.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2022-04-06"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2022-04-06_2022-04-06.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2022-04-07"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2022-04-07_2022-04-07.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2022-04-08"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2022-04-09_2022-04-09.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2022-04-10"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2022-04-10_2022-04-10.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2022-04-11"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2022-04-11_2022-04-11.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2022-04-12"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2022-04-12_2022-04-12.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2022-04-13"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2022-04-13_2022-04-13.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2022-04-14"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2022-04-14_2022-04-14.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2022-04-15"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2022-04-15_2022-04-15.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2022-04-16"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2022-04-16_2022-04-16.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2022-04-17"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2022-04-18_2022-04-18.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2022-04-19"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2022-04-19_2022-04-19.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2022-04-20"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2022-04-20_2022-04-20.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2022-04-21"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2022-04-21_2022-04-21.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2022-04-22"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2022-04-22_2022-04-22.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2022-04-23"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2022-04-23_2022-04-23.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2022-04-24"
. ./import_to_database.sh