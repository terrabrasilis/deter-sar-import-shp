#!/bin/bash
host=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=host=[^*])[^"]*')
port=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=port=[^*])[^"]*')
database=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=database=[^*])[^"]*')
user=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=user=[^*])[^"]*')
pass=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=password=[^*])[^"]*')
SCHEMA="deter_sar"
OUTPUT_SOURCE_TABLE="deter_sar_from_source"
DATE_LOG=$(date +"%Y-%m-%d_%H:%M:%S")

export PGUSER=$user
export PGPASSWORD=$pass

PG_BIN="/usr/bin"
PG_CON="-d $database -p $port -h $host"

echo
echo "=========================== $DATE_LOG ==========================="

# try read shapefile name from trigger file
if [[ -f "$INPUT_DIR/trigger.txt" ]];
then
  # get shapefile name
  SHP_NAME=$(cat $INPUT_DIR/trigger.txt)
else
  # hasn't a trigger file, aborting
  exit
fi

if [[ ! -f $INPUT_DIR"/"$SHP_NAME ]]; then
  echo "$DATE_LOG - Cannot find SHP($SHP_NAME), aborting..."
  exit
fi

# Define SQL to log the success operation. Tips to select datetime as a string (to_char(timezone('America/Sao_Paulo',imported_at),'YYYY-MM-DD HH24:MI:SS'))
SQL_LOG_IMPORT="INSERT INTO $SCHEMA.deter_sar_import_log(imported_at, filename) VALUES (timezone('America/Sao_Paulo',now()), '$SHP_NAME')"
# Find shapefile in log table
SQL_CHECK_FILE="SELECT 'YES' FROM $SCHEMA.deter_sar_import_log WHERE filename = '$SHP_NAME'"
# Options to create mode and default srid to input/output
SHP2PGSQL_OPTIONS="-c -s 4326:4326 -W 'LATIN1' -g geometries"

# find the shapename into log table
SHP_MATCHED=($($PG_BIN/psql $PG_CON -t -c "$SQL_CHECK_FILE"))

if [[ "0" = "$?" ]];
then
  echo "Conection ok..."

  if [[ ! "YES" = "$SHP_MATCHED" ]];
  then
    # copy deter-sar file to keep as backup
    cp -a $INPUT_DIR"/"$SHP_NAME "$SHARED_DIR/"
    unzip -j $SHARED_DIR"/"$SHP_NAME -d "$SHARED_DIR/"

    # get file name without extension
    SHP_NAME=${SHP_NAME%.*}
    # import shapefiles
    if $PG_BIN/shp2pgsql $SHP2PGSQL_OPTIONS $SHARED_DIR"/"$SHP_NAME $SCHEMA"."$OUTPUT_SOURCE_TABLE | $PG_BIN/psql $PG_CON
    then
        echo "$DATE_LOG - Import ($SHP_NAME) ... OK" >> "$SHARED_DIR/logs/import-shapefile.log"
        $PG_BIN/psql $PG_CON -t -c "$SQL_LOG_IMPORT"
        # remove uncompressed shp files
        rm ${SHARED_DIR}/${SHP_NAME}*.{shx,prj,shp,dbf,cpg,fix}
        # remove trigger file
        rm "$INPUT_DIR/trigger.txt"

        # Copy new SAR data to a full data table
        . ./copy_to_full_table.sh $OUTPUT_SOURCE_TABLE

        # process the difference between new SAR data and the production FM data
        #. ./make_diff_from_fm.sh $OUTPUT_SOURCE_TABLE
    else
        echo "$DATE_LOG - Import ($SHP_NAME) ... FAIL" >>"$SHARED_DIR/logs/import-shapefile.log"
    fi
  else
    echo "$DATE_LOG - The SHP($SHP_NAME) has been imported before." >> "$SHARED_DIR/logs/import-shapefile.log"
  fi

else
  echo "Conection failure..."
fi