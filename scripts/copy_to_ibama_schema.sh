#!/bin/bash
host=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=host=[^*])[^"]*')
port=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=port=[^*])[^"]*')
database=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=database=[^*])[^"]*')

DATE_TIME_LOG=$(date +"%Y-%m-%d_%H:%M:%S")
DATE_LOG=$(date +%Y-%m-%d)
LOGFILE="import_shapefile_$DATE_LOG.log"
MAIL_BODY="mail_body_$DATE_LOG"

PG_BIN="/usr/bin"
PG_CON="-d $database -p $port -h $host"

SCHEMA="deter_agregate"
OUTPUT_FINAL_TABLE="deter" # final data table used to send shapefile to the IBAMA
BASE_SCHEMA="deter_sar"
OUTPUT_SOURCE_TABLE="$1"

# new index to improve diff
CREATE_INDEX="""
CREATE INDEX ${OUTPUT_SOURCE_TABLE}_idx_geom
    ON $BASE_SCHEMA.$OUTPUT_SOURCE_TABLE USING gist
    (geometries)
    TABLESPACE pg_default;
"""

# Compute difference between DETER_R and DETER_B
CREATE_TABLE="""
CREATE TABLE $SCHEMA.by_percentage_of_coverage AS
SELECT null::integer as auditar, null::date as date_audit, intensity,
    n_alerts, daydetec, area_ha, label, class, now()::date as created_at, uuid,
	  (ST_Multi(ST_CollectionExtract(
		COALESCE(
		  safe_diff(a.geometries,
			( SELECT st_union(st_buffer(b.geom,0.000000001))
			  FROM $SCHEMA.deter b
			  WHERE
				b.source='D'
				AND b.classname IN ('DESMATAMENTO_VEG','DESMATAMENTO_CR','MINERACAO')
				AND (a.geometries && b.geom)
			)
		  ),
		  a.geometries
		)
	  ,3))
	  ) AS geom_diff,
	  a.geometries as geom_original
FROM $BASE_SCHEMA.$OUTPUT_SOURCE_TABLE a;
"""

UPDATE_AREA="""
UPDATE $SCHEMA.by_percentage_of_coverage SET area_ha=ST_area(geom_original::geography)/10000;
"""

# DETER_R alerts are marked as audited by default when DETER_B coverage is greater than or equal to 50% 
THRESHOLD="0.5"
WITHOUT_AUDIT="""
WITH calculate_area AS (
	SELECT ST_Area(geom_diff::geography)/10000 as area_diff,ST_Area(geom_original::geography)/10000 as area_original, uuid
	FROM $SCHEMA.by_percentage_of_coverage
)
UPDATE $SCHEMA.by_percentage_of_coverage
SET auditar=0, date_audit=now()::date
FROM calculate_area b
WHERE $SCHEMA.by_percentage_of_coverage.uuid=b.uuid AND b.area_diff < (b.area_original*$THRESHOLD)
"""

# the 100 candidates by bigger areas
LIMIT="100"
CANDIDATES_BY_AREA="""
UPDATE $SCHEMA.by_percentage_of_coverage
SET auditar=1
WHERE uuid IN (
	SELECT uuid FROM $SCHEMA.by_percentage_of_coverage
  WHERE auditar IS NULL AND date_audit IS NULL ORDER BY area_ha DESC LIMIT $LIMIT
)
"""

# the 300 candidates by random
LIMIT="300"
CANDIDATES_BY_RANDOM="""
UPDATE $SCHEMA.by_percentage_of_coverage
SET auditar=1
WHERE uuid IN (
	SELECT uuid FROM $SCHEMA.by_percentage_of_coverage
  WHERE auditar IS NULL AND date_audit IS NULL ORDER BY random() LIMIT $LIMIT
)
"""

# change the class column to accept updating the class name
ALTER_CLASS_COL="""
ALTER TABLE $SCHEMA.by_percentage_of_coverage
ALTER COLUMN class TYPE character varying(50);
"""

MAP_CLASS_NAME_CLEAR_CUT="""
UPDATE $SCHEMA.by_percentage_of_coverage SET class='DESMATAMENTO_CR'
WHERE class='CLEAR_CUT';
"""

MAP_CLASS_NAME_DEGRADATION="""
UPDATE $SCHEMA.by_percentage_of_coverage SET class='DESMATAMENTO_VEG'
WHERE class='DEGRADATION';
"""

# copy to final table OUTPUT_FINAL_TABLE
COPY_TO_FINAL_TABLE="""
INSERT INTO $SCHEMA.$OUTPUT_FINAL_TABLE
(uuid, classname, geom, satellite, sensor, source, view_date, areatotalkm, areamunkm, created_at, auditar, date_audit)
SELECT uuid, class, geom_original as geom, 'Sentinel-1' as satellite, 'C-SAR' as sensor, 'S' as source,
((('2020-01-01'::date) + (daydetec||' day')::interval)::date) as view_date,
area_ha/100 as areatotalkm, area_ha/100 as areamunkm, created_at, auditar, date_audit
FROM $SCHEMA.by_percentage_of_coverage
"""

DROP_TMP_TABLE="DROP TABLE $SCHEMA.by_percentage_of_coverage"

# result to send inside email
SELECT_RESULT="""
SELECT count(*) 
FROM $SCHEMA.$OUTPUT_FINAL_TABLE
WHERE created_at>=now()::date and source='S' and auditar=1
"""

# create index to improve diff process 
$PG_BIN/psql $PG_CON -t -c "$CREATE_INDEX"
# create the intermeriary table for SAR without overlap
$PG_BIN/psql $PG_CON -t -c "$CREATE_TABLE"
# update area
$PG_BIN/psql $PG_CON -t -c "$UPDATE_AREA"

# Marked as audited by default when coverage is greater than or equal to 50% (auditar=1)
$PG_BIN/psql $PG_CON -t -c "$WITHOUT_AUDIT"
echo "$DATE_TIME_LOG - Marked as audited by default when coverage is greater than or equal to 50%" >> "$SHARED_DIR/logs/$LOGFILE"

# Update audit to 1 to the first 100 candidates
$PG_BIN/psql $PG_CON -t -c "$CANDIDATES_BY_AREA"
echo "$DATE_TIME_LOG - Define the first 100 candidates" >> "$SHARED_DIR/logs/$LOGFILE"

# Update audit to 1 to the random 300 candidates
$PG_BIN/psql $PG_CON -t -c "$CANDIDATES_BY_RANDOM"
echo "$DATE_TIME_LOG - Define the random 300 candidates" >> "$SHARED_DIR/logs/$LOGFILE"

# Change class column
$PG_BIN/psql $PG_CON -t -c "$ALTER_CLASS_COL"
echo "$DATE_TIME_LOG - Change the class column to accept updating the class name" >> "$SHARED_DIR/logs/$LOGFILE"

# Update the class name CLEAR_CUT to DESMATAMENTO_CR
$PG_BIN/psql $PG_CON -t -c "$MAP_CLASS_NAME_CLEAR_CUT"
echo "$DATE_TIME_LOG - Update the class name CLEAR_CUT to DESMATAMENTO_CR on $OUTPUT_INTERMEDIARY_TABLE" >> "$SHARED_DIR/logs/$LOGFILE"

# Update the class name DEGRADATION to DESMATAMENTO_VEG
$PG_BIN/psql $PG_CON -t -c "$MAP_CLASS_NAME_DEGRADATION"
echo "$DATE_TIME_LOG - Update the class name DEGRADATION to DESMATAMENTO_VEG on $OUTPUT_INTERMEDIARY_TABLE" >> "$SHARED_DIR/logs/$LOGFILE"

# Copy data to final table
$PG_BIN/psql $PG_CON -t -c "$COPY_TO_FINAL_TABLE"
echo "$DATE_TIME_LOG - Copy data from $OUTPUT_INTERMEDIARY_TABLE to $OUTPUT_FINAL_TABLE" >> "$SHARED_DIR/logs/$LOGFILE"

# drop the temporary table
$PG_BIN/psql $PG_CON -t -c "$DROP_TMP_TABLE"
echo "$DATE_TIME_LOG - Drop the temporary table (by_percentage_of_coverage)" >> "$SHARED_DIR/logs/$LOGFILE"

# read the final data table to send over email
PRINT_AUDIT_DATA=($($PG_BIN/psql $PG_CON -c "$SELECT_RESULT"))
echo "Caro usuário," > "$SHARED_DIR/logs/$MAIL_BODY"
echo "Foram liberados $PRINT_AUDIT_DATA poligonos para auditar" >> "$SHARED_DIR/logs/$MAIL_BODY"
echo "" >> "$SHARED_DIR/logs/$MAIL_BODY"
echo "Acesse: http://www.dpi.inpe.br/fipcerrado/detersar/" >> "$SHARED_DIR/logs/$MAIL_BODY"
echo "" >> "$SHARED_DIR/logs/$MAIL_BODY"
echo "Att.: TerraBrasilis team" >> "$SHARED_DIR/logs/$MAIL_BODY"

# send mail to team based on "$SHARED_DIR"/mail_to.cfg file
. ./send-mail.sh "$SHARED_DIR/logs/$MAIL_BODY"