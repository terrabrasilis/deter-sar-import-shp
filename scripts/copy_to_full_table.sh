#!/bin/bash
host=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=host=[^*])[^"]*')
port=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=port=[^*])[^"]*')
database=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=database=[^*])[^"]*')
user=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=user=[^*])[^"]*')
pass=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=password=[^*])[^"]*')
DATE_LOG=$(date +"%Y-%m-%d_%H:%M:%S")

PG_BIN="/usr/bin"
PG_CON="-d $database -p $port -h $host"

SCHEMA="deter_sar"
FULL_TABLE="deter_sar_amz"
OUTPUT_SOURCE_TABLE="$1"

COPY_TO_FULL_TABLE="""
INSERT INTO $SCHEMA.$FULL_TABLE
(geometries, intensity, n_alerts, daydetec, area_ha, label, class)
SELECT geometries, intensity, n_alerts, daydetec, area_ha, label, class
FROM $SCHEMA.$OUTPUT_SOURCE_TABLE;
"""

DROP_SOURCE_TABLE="DROP TABLE $SCHEMA.$OUTPUT_SOURCE_TABLE"

# copy SAR data to full AMZ output table
$PG_BIN/psql $PG_CON -t -c "$COPY_TO_FULL_TABLE"
echo "$DATE_LOG - Copy SAR data to $SCHEMA.$FULL_TABLE" >> "$SHARED_DIR/logs/import-shapefile.log"

# drop the intermediary table
$PG_BIN/psql $PG_CON -t -c "$DROP_SOURCE_TABLE"
echo "$DATE_LOG - Drop intermediary table ($SCHEMA.$OUTPUT_SOURCE_TABLE)" >> "$SHARED_DIR/logs/import-shapefile.log"