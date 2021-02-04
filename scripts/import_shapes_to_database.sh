#!/bin/bash
host=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=host=[^*])[^"]*')
port=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=port=[^*])[^"]*')
database=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=database=[^*])[^"]*')
user=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=user=[^*])[^"]*')
pass=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=password=[^*])[^"]*')
OUTPUT_SOURCE_TABLE="deter_sar_from_source"
DATE_LOG=$(date +"%Y-%m-%d_%H:%M:%S")

export PGUSER=$user
export PGPASSWORD=$pass

PG_BIN="/usr/bin"
PG_CON="-d $database -p $port -h $host"

echo
echo "=========================== $DATE_LOG ==========================="

# define shapefile name
YESTERDAY=$(date -d '1 day ago' '+%Y-%m-%d')
# try read start and end date from file
if [[ -f "$INPUT_DIR/overwrite_period" ]];
then
  START_DATE=$(cat $INPUT_DIR/overwrite_period | grep -oP '(?<=start_date=[^*])[^"]*')
  END_DATE=$(cat $INPUT_DIR/overwrite_period | grep -oP '(?<=end_date=[^*])[^"]*')
  mv "$INPUT_DIR/overwrite_period" "$INPUT_DIR/overwrite_period.done"
else
  START_DATE=$YESTERDAY
  END_DATE=$YESTERDAY
fi

SHP_NAME="DETERSAR_CR2_$START_DATE"_"$END_DATE"
if [[ ! -f $INPUT_DIR"/"$SHP_NAME".zip" ]]; then
  echo "$DATE_LOG - Cannot find SHP($SHP_NAME), aborting..."
  exit
fi

# Define SQL to log the success operation. Tips to select datetime as a string (to_char(timezone('America/Sao_Paulo',imported_at),'YYYY-MM-DD HH24:MI:SS'))
SQL_LOG_IMPORT="INSERT INTO public.deter_sar_import_log(imported_at, filename) VALUES (timezone('America/Sao_Paulo',now()), '$SHP_NAME')"
# Find shapefile in log table
SQL_CHECK_FILE="SELECT 'YES' FROM public.deter_sar_import_log WHERE filename = '$SHP_NAME'"
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
    cp -a $INPUT_DIR"/"$SHP_NAME".zip" "$SHARED_DIR/"
    unzip -j $SHARED_DIR"/"$SHP_NAME".zip" -d "$SHARED_DIR/"
    # import shapefiles
    if $PG_BIN/shp2pgsql $SHP2PGSQL_OPTIONS $SHARED_DIR"/"$SHP_NAME $OUTPUT_SOURCE_TABLE | $PG_BIN/psql $PG_CON
    then
        echo "$DATE_LOG - Import ($SHP_NAME) ... OK" >> "$SHARED_DIR/logs/import-shapefile.log"
        $PG_BIN/psql $PG_CON -t -c "$SQL_LOG_IMPORT"
        # remove uncompressed shp files
        rm ${SHARED_DIR}/${SHP_NAME}*.{shx,prj,shp,dbf,cpg,fix}

        # process the difference between new SAR data and the production FM data
        . ./make_diff_from_fm.sh $OUTPUT_SOURCE_TABLE
    else
        echo "$DATE_LOG - Import ($SHP_NAME) ... FAIL" >>"$SHARED_DIR/logs/import-shapefile.log"
    fi
  else
    echo "$DATE_LOG - The SHP($SHP_NAME) has been imported before." >> "$SHARED_DIR/logs/import-shapefile.log"
  fi

else
  echo "Conection failure..."
fi