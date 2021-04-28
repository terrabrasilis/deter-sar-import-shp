#!/bin/bash
host=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=host=[^*])[^"]*')
port=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=port=[^*])[^"]*')
database=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=database=[^*])[^"]*')

DATE_LOG=$(date +"%Y-%m-%d_%H:%M:%S")

PG_BIN="/usr/bin"
PG_CON="-d $database -p $port -h $host"

SCHEMA="deter_agregate"
OUTPUT_FINAL_TABLE="deter" # final data table used to send shapefile to the IBAMA
OUTPUT_INTERMEDIARY_TABLE="deter_sar_1ha"
BASE_SCHEMA="deter_sar"
OUTPUT_SOURCE_TABLE="$1"

# new index to improve diff
CREATE_INDEX="""
CREATE INDEX ${OUTPUT_SOURCE_TABLE}_idx_geom
    ON $BASE_SCHEMA.$OUTPUT_SOURCE_TABLE USING gist
    (geometries)
    TABLESPACE pg_default;
"""
# to process the difference between new SAR data and the production DETER-B data
CREATE_TABLE="""
CREATE TABLE $SCHEMA.deter_sar_without_overlap AS
  SELECT uuid, gid, n_alerts, daydetec, area_ha, label, class,
  (st_dump(
  COALESCE(
    safe_diff(a.geometries,
      (SELECT st_union(st_buffer(b.geom,0.000000001))
       FROM $SCHEMA.deter b
       WHERE
        b.source='D'
	      AND b.classname IN ('DESMATAMENTO_VEG','DESMATAMENTO_CR','MINERACAO')
        AND (a.geometries && b.geom)
     )
    ),
  a.geometries))).geom AS geom
FROM $BASE_SCHEMA.$OUTPUT_SOURCE_TABLE a;
"""

UPDATE_AREA="""
UPDATE $SCHEMA.deter_sar_without_overlap SET area_ha=ST_area(geom::geography)/10000;
"""

COPY_ALL="""
INSERT INTO $SCHEMA.$OUTPUT_INTERMEDIARY_TABLE
(geometries, n_alerts, daydetec, area_ha, label, class, auditar, uuid)
SELECT ST_Multi(geom) as geometries, n_alerts, daydetec, area_ha, label, class, 0 as auditar, uuid
FROM $SCHEMA.deter_sar_without_overlap WHERE area_ha>=1;
"""

# the 100 candidates by bigger areas
LIMIT="100"
CANDIDATES_BY_AREA="""
WITH candidates_by_area AS (
  SELECT gid, area_ha
  FROM $SCHEMA.$OUTPUT_INTERMEDIARY_TABLE
  WHERE created_at=now()::date
  ORDER BY area_ha DESC
  LIMIT $LIMIT
)
UPDATE $SCHEMA.$OUTPUT_INTERMEDIARY_TABLE SET auditar=1
WHERE gid IN (SELECT gid FROM candidates_by_area)
"""

# the 300 candidates by random
LIMIT="300"
CANDIDATES_BY_RANDOM="""
WITH candidates_by_random AS (
  SELECT gid, area_ha
  FROM $SCHEMA.$OUTPUT_INTERMEDIARY_TABLE
  WHERE created_at=now()::date
  AND auditar=0
  ORDER BY random()
  LIMIT $LIMIT
)
UPDATE $SCHEMA.$OUTPUT_INTERMEDIARY_TABLE SET auditar=1
WHERE gid IN (SELECT gid FROM candidates_by_random)
"""

MAP_CLASS_NAME_CLEAR_CUT="""
UPDATE $SCHEMA.$OUTPUT_INTERMEDIARY_TABLE SET class='DESMATAMENTO_CR'
WHERE class='CLEAR_CUT';
"""

MAP_CLASS_NAME_DEGRADATION="""
UPDATE $SCHEMA.$OUTPUT_INTERMEDIARY_TABLE SET class='DESMATAMENTO_VEG'
WHERE class='DEGRADATION';
"""

# copy to final table OUTPUT_FINAL_TABLE
COPY_TO_FINAL_TABLE="""
INSERT INTO $SCHEMA.$OUTPUT_FINAL_TABLE
(uuid, classname, geom, satellite, sensor, source, view_date, areatotalkm, areamunkm, created_at, auditar)
SELECT uuid, class, geom, 'Sentinel-1' as satellite, 'C-SAR' as sensor, 'S' as source,
((('$REFERECE_YEAR_FOR_JDAY'::date) + (daydetec||' day')::interval)::date) as view_date,
area_ha/100 as areatotalkm, area_ha/100 as areamunkm, created_at, auditar
FROM $SCHEMA.$OUTPUT_INTERMEDIARY_TABLE
"""

DELETE_INTERMEDIARY_DATA="DELETE FROM $SCHEMA.$OUTPUT_INTERMEDIARY_TABLE"
DROP_TMP_TABLE="DROP TABLE $SCHEMA.deter_sar_without_overlap"

# create index to improve diff process 
$PG_BIN/psql $PG_CON -t -c "$CREATE_INDEX"
# create the intermeriary table for SAR without overlap
$PG_BIN/psql $PG_CON -t -c "$CREATE_TABLE"
# update area
$PG_BIN/psql $PG_CON -t -c "$UPDATE_AREA"

# copy SAR data to output table
$PG_BIN/psql $PG_CON -t -c "$COPY_ALL"
echo "$DATE_LOG - Copy all alerts from the SAR data to $OUTPUT_INTERMEDIARY_TABLE" >> "$SHARED_DIR/logs/import-shapefile.log"

# Update audit to 1 to the first 100 candidates
$PG_BIN/psql $PG_CON -t -c "$CANDIDATES_BY_AREA"
echo "$DATE_LOG - Define the first 100 candidates on $OUTPUT_INTERMEDIARY_TABLE" >> "$SHARED_DIR/logs/import-shapefile.log"

# Update audit to 1 to the random 300 candidates
$PG_BIN/psql $PG_CON -t -c "$CANDIDATES_BY_RANDOM"
echo "$DATE_LOG - Define the random 300 candidates on $OUTPUT_INTERMEDIARY_TABLE" >> "$SHARED_DIR/logs/import-shapefile.log"

# drop the intermediary table
$PG_BIN/psql $PG_CON -t -c "$DROP_TMP_TABLE"
echo "$DATE_LOG - Drop intermediary tables ($DROP_TMP_TABLE)" >> "$SHARED_DIR/logs/import-shapefile.log"


