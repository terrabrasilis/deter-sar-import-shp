#!/bin/bash
host=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=host=[^*])[^"]*')
port=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=port=[^*])[^"]*')
database=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=database=[^*])[^"]*')

DATE_LOG=$(date +"%Y-%m-%d_%H:%M:%S")

PG_BIN="/usr/bin"
PG_CON="-d $database -p $port -h $host"

SCHEMA="deter_sar"
OUTPUT_SOURCE_TABLE="$1"

DROP_SOURCE_TABLE="DROP TABLE $SCHEMA.$OUTPUT_SOURCE_TABLE"

# drop the intermediary table
$PG_BIN/psql $PG_CON -t -c "$DROP_SOURCE_TABLE"
echo "$DATE_LOG - Drop intermediary table ($SCHEMA.$OUTPUT_SOURCE_TABLE)" >> "$SHARED_DIR/logs/import-input-file.log"