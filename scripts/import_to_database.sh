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
OGR_PG_CON="dbname='$database' host='$host' port='$port' user='$user' password='$pass'"

echo
echo "=========================== $DATE_LOG ==========================="

# try read input file name from trigger file
if [[ -f "$INPUT_DIR/trigger.txt" ]];
then
  # get input file name
  INPUT_FILE=$(cat $INPUT_DIR/trigger.txt)
else
  # hasn't a trigger file, aborting
  exit
fi

if [[ ! -f $INPUT_DIR"/"$INPUT_FILE ]]; then
  echo "$DATE_LOG - Cannot find INPUT_FILE($INPUT_FILE), aborting..."
  exit
fi

# gen_random_uuid depends on the pgcrypto extension in some versions of PostgreSQL
ADD_UUID="""
ALTER TABLE $SCHEMA.$OUTPUT_SOURCE_TABLE
ADD COLUMN uuid uuid NOT NULL DEFAULT gen_random_uuid();
"""
# Define SQL to log the success operation. Tips to select datetime as a string (to_char(timezone('America/Sao_Paulo',imported_at),'YYYY-MM-DD HH24:MI:SS'))
SQL_LOG_IMPORT="INSERT INTO $SCHEMA.deter_sar_import_log(imported_at, filename) VALUES (timezone('America/Sao_Paulo',now()), '$INPUT_FILE')"
# Find input file in log table
SQL_CHECK_FILE="SELECT 'YES' FROM $SCHEMA.deter_sar_import_log WHERE filename = '$INPUT_FILE'"
# Options to create mode and default srid to input/output
OGR_OPTIONS="-t_srs EPSG:4674 -lco GEOMETRY_NAME=geometries -nln $SCHEMA.$OUTPUT_SOURCE_TABLE"
SHP2PGSQL_OPTIONS="-c -s 4326:4674 -W 'LATIN1' -g geometries"

# find the input file into log table
FILE_MATCHED=($($PG_BIN/psql $PG_CON -t -c "$SQL_CHECK_FILE"))
IMPORT_CTRL=false

if [[ "0" = "$?" ]];
then
  echo "Conection ok..."

  if [[ ! "YES" = "$FILE_MATCHED" ]];
  then
    # copy deter-sar file to keep as backup
    cp -a $INPUT_DIR"/"$INPUT_FILE "$SHARED_DIR/"

    # split file name and extension
    EXTENSION="${INPUT_FILE##*.}"
    FILE_NAME="${INPUT_FILE%.*}"
    if [[ "$EXTENSION" = "zip" ]]; then
      unzip -j $SHARED_DIR"/"$INPUT_FILE -d "$SHARED_DIR/"
      # import shapefiles
      if $PG_BIN/shp2pgsql $SHP2PGSQL_OPTIONS $SHARED_DIR"/"$FILE_NAME $SCHEMA"."$OUTPUT_SOURCE_TABLE | $PG_BIN/psql $PG_CON
      then
        IMPORT_CTRL=true
      fi
    else
      # import geojson file
      if $PG_BIN/ogr2ogr -f "PostgreSQL" PG:"$OGR_PG_CON" $SHARED_DIR"/"$INPUT_FILE $OGR_OPTIONS
      then
        IMPORT_CTRL=true
      fi
    fi

    # control to check the file import
    if [ $IMPORT_CTRL = true ]; then
        echo "$DATE_LOG - Import ($INPUT_FILE) ... OK" >> "$SHARED_DIR/logs/import-input-file.log"
        $PG_BIN/psql $PG_CON -t -c "$SQL_LOG_IMPORT"
        $PG_BIN/psql $PG_CON -t -c "$ADD_UUID"

        # remove uncompressed shp files
        if [[ "$EXTENSION" = "zip" ]]; then
          rm ${SHARED_DIR}/${FILE_NAME}*.{shx,prj,shp,dbf,cpg,fix}
        fi
        # remove trigger file
        rm "$INPUT_DIR/trigger.txt"

        # Copy new SAR data to a full data table
        . ./copy_to_full_table.sh $OUTPUT_SOURCE_TABLE

        # Make diff with DETER-B and copy new SAR data to a temporary data table
        # Used by Maurano's script to compose with DETER-B and compute the speed of deforestation for IBAMA
        . ./copy_to_ibama_schema.sh $OUTPUT_SOURCE_TABLE

        # Clean intermediary table
        . ./clean.sh $OUTPUT_SOURCE_TABLE
    else
        echo "$DATE_LOG - Import ($INPUT_FILE) ... FAIL" >>"$SHARED_DIR/logs/import-input-file.log"
    fi
  else
    echo "$DATE_LOG - The INPUT_FILE($INPUT_FILE) has been imported before." >> "$SHARED_DIR/logs/import-input-file.log"
  fi

else
  echo "Conection failure..."
fi