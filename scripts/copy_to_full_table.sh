#!/bin/bash
host=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=host=[^*])[^"]*')
port=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=port=[^*])[^"]*')
database=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=database=[^*])[^"]*')

DATE_LOG=$(date +"%Y-%m-%d_%H:%M:%S")

PG_BIN="/usr/bin"
PG_CON="-d $database -p $port -h $host"

SCHEMA="deter_sar"
FULL_TABLE="deter_sar_amz"
OUTPUT_SOURCE_TABLE="$1"

REFERECE_YEAR_FOR_JDAY="2020-01-01"

COPY_TO_FULL_TABLE="""
INSERT INTO $SCHEMA.$FULL_TABLE
(geometries, intensity, n_alerts, daydetec, area_ha, label, class, view_date, uuid)
SELECT geometries, intensity, n_alerts, daydetec, area_ha, label, class,
((('$REFERECE_YEAR_FOR_JDAY'::date) + (daydetec||' day')::interval)::date) as view_date, uuid
FROM $SCHEMA.$OUTPUT_SOURCE_TABLE;
"""
# copy SAR data to full AMZ output table
$PG_BIN/psql $PG_CON -t -c "$COPY_TO_FULL_TABLE"
echo "$DATE_LOG - Copy SAR data to $SCHEMA.$FULL_TABLE" >> "$SHARED_DIR/logs/import-input-file.log"