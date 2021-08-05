#!/bin/bash
host=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=host=[^*])[^"]*')
port=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=port=[^*])[^"]*')
database=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=database=[^*])[^"]*')

DATE_TIME_LOG=$(date +"%Y-%m-%d_%H:%M:%S")
DATE_LOG=$(date +%Y-%m-%d)
LOGFILE="copy_to_ibama_$DATE_LOG.log"
MAIL_BODY="mail_body_$DATE_LOG"

PG_BIN="/usr/bin"
PG_CON="-d $database -p $port -h $host"

SCHEMA="deter_agregate"
OUTPUT_FINAL_TABLE="deter" # final data table used to send shapefile to the IBAMA
AUDITED_TABLE="deter_sar_1ha_validados"
OUTPUT_INTERMEDIARY_TABLE="by_percentage_of_coverage"
BASE_SCHEMA="deter_sar"
OUTPUT_SOURCE_TABLE="$1"

# if created_at is defined from manual import
if [[ -v CREATED_AT ]]; then
	REFERENCE_DATE="'${CREATED_AT}'"
else
	REFERENCE_DATE="now()"
fi

# new index to improve diff
CREATE_INDEX="""
CREATE INDEX ${OUTPUT_SOURCE_TABLE}_idx_geom
    ON $BASE_SCHEMA.$OUTPUT_SOURCE_TABLE USING gist
    (geometries)
    TABLESPACE pg_default;
"""

# Compute difference between DETER_R and DETER_B
CREATE_TABLE="""
CREATE TABLE $SCHEMA.$OUTPUT_INTERMEDIARY_TABLE AS
SELECT ''::character varying as nome_avaliador, null::integer as auditar, null::date as date_audit, intensity,
    n_alerts, daydetec, area_ha, label, class, $REFERENCE_DATE::date as created_at, uuid,
	  (ST_Multi(ST_CollectionExtract(
		COALESCE(
		  safe_diff(a.geometries,
			( SELECT st_union(st_buffer(b.geom,0.000000001))
			  FROM $SCHEMA.deter b
			  WHERE
				b.source='D'
				AND b.classname IN ('DESMATAMENTO_VEG','DESMATAMENTO_CR','MINERACAO')
				AND created_at<=$REFERENCE_DATE::date
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
UPDATE $SCHEMA.$OUTPUT_INTERMEDIARY_TABLE SET area_ha=ST_area(geom_original::geography)/10000;
"""

# DETER_R alerts are marked as audited by default when DETER_B coverage is greater than or equal to 50% 
THRESHOLD="0.5"
WITHOUT_AUDIT="""
WITH calculate_area AS (
	SELECT ST_Area(geom_diff::geography)/10000 as area_diff,ST_Area(geom_original::geography)/10000 as area_original, uuid
	FROM $SCHEMA.$OUTPUT_INTERMEDIARY_TABLE
)
UPDATE $SCHEMA.$OUTPUT_INTERMEDIARY_TABLE
SET auditar=0, date_audit=$REFERENCE_DATE::date, nome_avaliador='automatico'
FROM calculate_area b
WHERE $SCHEMA.$OUTPUT_INTERMEDIARY_TABLE.uuid=b.uuid AND b.area_diff < (b.area_original*$THRESHOLD)
"""

# the 100 candidates by bigger areas
LIMIT="100"
CANDIDATES_BY_AREA="""
UPDATE $SCHEMA.$OUTPUT_INTERMEDIARY_TABLE
SET auditar=1
WHERE uuid IN (
	SELECT uuid FROM $SCHEMA.$OUTPUT_INTERMEDIARY_TABLE
  WHERE auditar IS NULL AND date_audit IS NULL ORDER BY area_ha DESC LIMIT $LIMIT
)
"""

# the 300 candidates by random
LIMIT="300"
CANDIDATES_BY_RANDOM="""
UPDATE $SCHEMA.$OUTPUT_INTERMEDIARY_TABLE
SET auditar=1
WHERE uuid IN (
	SELECT uuid FROM $SCHEMA.$OUTPUT_INTERMEDIARY_TABLE
  WHERE auditar IS NULL AND date_audit IS NULL ORDER BY random() LIMIT $LIMIT
)
"""

# Set auditar=0 for anyone who is still null after applying the rules
ANYONE_STILL_NULL="""
UPDATE $SCHEMA.$OUTPUT_INTERMEDIARY_TABLE
SET auditar=0
WHERE auditar IS NULL AND date_audit IS NULL
"""

# change the class column to accept updating the class name
ALTER_CLASS_COL="""
ALTER TABLE $SCHEMA.$OUTPUT_INTERMEDIARY_TABLE
ALTER COLUMN class TYPE character varying(50);
"""

MAP_CLASS_NAME_CLEAR_CUT="""
UPDATE $SCHEMA.$OUTPUT_INTERMEDIARY_TABLE SET class='DESMATAMENTO_CR'
WHERE class='CLEAR_CUT';
"""

MAP_CLASS_NAME_DEGRADATION="""
UPDATE $SCHEMA.$OUTPUT_INTERMEDIARY_TABLE SET class='DEGRADACAO'
WHERE class='DEGRADATION';
"""

# copy to final table OUTPUT_FINAL_TABLE
COPY_TO_FINAL_TABLE="""
INSERT INTO $SCHEMA.$OUTPUT_FINAL_TABLE
(uuid, classname, geom, satellite, sensor, source, view_date, areatotalkm, areamunkm, created_at, auditar, date_audit)
SELECT uuid, class, geom_original as geom, 'Sentinel-1' as satellite, 'C-SAR' as sensor, 'S' as source,
((('$REFERECE_YEAR_FOR_JDAY'::date) + (daydetec||' day')::interval)::date) as view_date,
area_ha/100 as areatotalkm, area_ha/100 as areamunkm, created_at, auditar, date_audit
FROM $SCHEMA.$OUTPUT_INTERMEDIARY_TABLE
"""

# copy the automated audited entries to the audited table
COPY_TO_ADITED="""
INSERT INTO $SCHEMA.$AUDITED_TABLE(
uuid, lon, lat, area_ha, view_date, classname, nome_avaliador, classe_avaliador, data_avaliacao, geom, created_at)
SELECT uuid, ST_X(ST_Centroid(geom_original)) as lon, ST_Y(ST_Centroid(geom_original)) as lat, area_ha,
((('$REFERECE_YEAR_FOR_JDAY'::date) + (daydetec||' day')::interval)::date) as view_date,
class, nome_avaliador, class, date_audit, geom_original as geom, created_at
FROM $SCHEMA.$OUTPUT_INTERMEDIARY_TABLE
WHERE auditar=0 AND date_audit IS NOT NULL;
"""

DROP_TMP_TABLE="DROP TABLE $SCHEMA.$OUTPUT_INTERMEDIARY_TABLE"

# Number of alerts sent to audit 
SELECT_RESULT1="""
SELECT count(*) 
FROM $SCHEMA.$OUTPUT_FINAL_TABLE
WHERE created_at>=$REFERENCE_DATE::date AND source='S' AND auditar=1
"""

# Number of alerts approved by automatic audit
SELECT_RESULT2="""
SELECT count(*) 
FROM $SCHEMA.$AUDITED_TABLE
WHERE created_at>=$REFERENCE_DATE::date AND nome_avaliador='automatico'
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

# Update the audit to 0 for the residual
$PG_BIN/psql $PG_CON -t -c "$ANYONE_STILL_NULL"
echo "$DATE_TIME_LOG - Update the auditar to 0 for the residual" >> "$SHARED_DIR/logs/$LOGFILE"

# Change class column
$PG_BIN/psql $PG_CON -t -c "$ALTER_CLASS_COL"
echo "$DATE_TIME_LOG - Change the class column to accept updating the class name" >> "$SHARED_DIR/logs/$LOGFILE"

# Update the class name CLEAR_CUT to DESMATAMENTO_CR
$PG_BIN/psql $PG_CON -t -c "$MAP_CLASS_NAME_CLEAR_CUT"
echo "$DATE_TIME_LOG - Update the class name CLEAR_CUT to DESMATAMENTO_CR on $OUTPUT_INTERMEDIARY_TABLE" >> "$SHARED_DIR/logs/$LOGFILE"

# Update the class name DEGRADATION to DEGRADACAO
$PG_BIN/psql $PG_CON -t -c "$MAP_CLASS_NAME_DEGRADATION"
echo "$DATE_TIME_LOG - Update the class name DEGRADATION to DEGRADACAO on $OUTPUT_INTERMEDIARY_TABLE" >> "$SHARED_DIR/logs/$LOGFILE"

# Copy data to final table
$PG_BIN/psql $PG_CON -t -c "$COPY_TO_FINAL_TABLE"
echo "$DATE_TIME_LOG - Copy data from $OUTPUT_INTERMEDIARY_TABLE to $OUTPUT_FINAL_TABLE" >> "$SHARED_DIR/logs/$LOGFILE"

# Copy the auto audited data to the audited table
$PG_BIN/psql $PG_CON -t -c "$COPY_TO_ADITED"
echo "$DATE_TIME_LOG - Copy data from $OUTPUT_INTERMEDIARY_TABLE to $AUDITED_TABLE" >> "$SHARED_DIR/logs/$LOGFILE"

# drop the temporary table
$PG_BIN/psql $PG_CON -t -c "$DROP_TMP_TABLE"
echo "$DATE_TIME_LOG - Drop the temporary table ($OUTPUT_INTERMEDIARY_TABLE)" >> "$SHARED_DIR/logs/$LOGFILE"

# read the final data table to send over email
PRINT_AUDIT_DATA1=($($PG_BIN/psql $PG_CON -At -c "$SELECT_RESULT1"))
PRINT_AUDIT_DATA2=($($PG_BIN/psql $PG_CON -At -c "$SELECT_RESULT2"))
echo "Caro usuario," > "$SHARED_DIR/logs/$MAIL_BODY"
echo "Foram liberados $PRINT_AUDIT_DATA1 poligonos para auditar" >> "$SHARED_DIR/logs/$MAIL_BODY"
echo "Poligonos auditado automaticamente: $PRINT_AUDIT_DATA2" >> "$SHARED_DIR/logs/$MAIL_BODY"
echo "" >> "$SHARED_DIR/logs/$MAIL_BODY"
echo "Acesse: http://www.dpi.inpe.br/fipcerrado/detersar/" >> "$SHARED_DIR/logs/$MAIL_BODY"
echo "" >> "$SHARED_DIR/logs/$MAIL_BODY"
echo "Att.: TerraBrasilis team" >> "$SHARED_DIR/logs/$MAIL_BODY"

# send mail to team based on "$SHARED_DIR"/mail_to.cfg file
. ./send-mail.sh "$SHARED_DIR/logs/$MAIL_BODY"