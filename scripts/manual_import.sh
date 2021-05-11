#!/bin/bash
# set env vars to use inside script
source /etc/environment
cd $INSTALL_PATH/scripts-shell

# disable sendmail
export EMAIL_CTRL=false

echo "DETER_R_AMZ_CR2_2021-04-20_2021-04-20.zip" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2021-04-21"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2021-04-21_2021-04-21.zip" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2021-04-22"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2021-04-22_2021-04-22.zip" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2021-04-23"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2021-04-23_2021-04-23.zip" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2021-04-24"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2021-04-24_2021-04-24.zip" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2021-04-25"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2021-04-25_2021-04-25.zip" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2021-04-26"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2021-04-26_2021-04-26.zip" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2021-04-27"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2021-04-27_2021-04-27.zip" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2021-04-28"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2021-04-28_2021-04-28.zip" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2021-04-29"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2021-04-29_2021-04-29.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2021-04-30"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2021-05-01_2021-05-01.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2021-05-02"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2021-05-02_2021-05-02.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2021-05-03"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2021-05-03_2021-05-03.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2021-05-04"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2021-05-04_2021-05-04.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2021-05-05"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2021-05-05_2021-05-05.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2021-05-06"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2021-05-06_2021-05-06.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2021-05-07"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2021-05-07_2021-05-07.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2021-05-08"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2021-05-08_2021-05-08.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2021-05-09"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2021-05-09_2021-05-09.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2021-05-10"
. ./import_to_database.sh

echo "DETER_R_AMZ_CR2_2021-05-10_2021-05-10.geojson" > "$INPUT_DIR/trigger.txt"
export CREATED_AT="2021-05-11"
. ./import_to_database.sh