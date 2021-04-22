#!/bin/bash
host=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=host=[^*])[^"]*')
port=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=port=[^*])[^"]*')
database=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=database=[^*])[^"]*')

DATE_LOG=$(date +"%Y-%m-%d_%H:%M:%S")

PG_BIN="/usr/bin"
PG_CON="-d $database -p $port -h $host"

SCHEMA="deter_agregate"
OUTPUT_FINAL_TABLE="deter_sar_1ha"
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
  SELECT gid, n_alerts, daydetec, area_ha, label, class,
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
FROM $BASE_SCHEMA.$OUTPUT_SOURCE_TABLE a
WHERE a.class='CLEAR_CUT';
"""

UPDATE_AREA="""
UPDATE $SCHEMA.deter_sar_without_overlap SET area_ha=ST_area(geom::geography)/10000;
"""

COPY_ALL="""
INSERT INTO $SCHEMA.$OUTPUT_FINAL_TABLE
(geometries, n_alerts, daydetec, area_ha, label, class, auditar)
SELECT ST_Multi(geom) as geometries, n_alerts, daydetec, area_ha, label, class, 0 as auditar
FROM $SCHEMA.deter_sar_without_overlap WHERE area_ha>=1;
"""

# the 100 candidates by bigger areas
LIMIT="100"
CANDIDATES_BY_AREA="""
WITH candidates_by_area AS (
  SELECT gid, area_ha
  FROM $SCHEMA.$OUTPUT_FINAL_TABLE
  WHERE created_at=now()::date
  ORDER BY area_ha DESC
  LIMIT $LIMIT
)
UPDATE $SCHEMA.$OUTPUT_FINAL_TABLE SET auditar=1
WHERE gid IN (SELECT gid FROM candidates_by_area)
"""

# the 300 candidates by random
LIMIT="300"
CANDIDATES_BY_RANDOM="""
WITH candidates_by_random AS (
  SELECT gid, area_ha
  FROM $SCHEMA.$OUTPUT_FINAL_TABLE
  WHERE created_at=now()::date
  AND auditar=0
  ORDER BY random()
  LIMIT $LIMIT
)
UPDATE $SCHEMA.$OUTPUT_FINAL_TABLE SET auditar=1
WHERE gid IN (SELECT gid FROM candidates_by_random)
"""

DROP_TMP_TABLE="DROP TABLE $SCHEMA.deter_sar_without_overlap"

# create index to improve diff process 
$PG_BIN/psql $PG_CON -t -c "$CREATE_INDEX"
# create the intermeriary table for SAR without overlap
$PG_BIN/psql $PG_CON -t -c "$CREATE_TABLE"
# update area
$PG_BIN/psql $PG_CON -t -c "$UPDATE_AREA"

# copy SAR data to output table
$PG_BIN/psql $PG_CON -t -c "$COPY_ALL"
echo "$DATE_LOG - Copy all alerts from the SAR data to $OUTPUT_FINAL_TABLE" >> "$SHARED_DIR/logs/import-shapefile.log"

# Update audit to 1 to the first 100 candidates
$PG_BIN/psql $PG_CON -t -c "$CANDIDATES_BY_AREA"
echo "$DATE_LOG - Define the first 100 candidates on $OUTPUT_FINAL_TABLE" >> "$SHARED_DIR/logs/import-shapefile.log"

# Update audit to 1 to the random 300 candidates
$PG_BIN/psql $PG_CON -t -c "$CANDIDATES_BY_RANDOM"
echo "$DATE_LOG - Define the random 300 candidates on $OUTPUT_FINAL_TABLE" >> "$SHARED_DIR/logs/import-shapefile.log"

# drop the intermediary table
$PG_BIN/psql $PG_CON -t -c "$DROP_TMP_TABLE"
echo "$DATE_LOG - Drop intermediary tables ($DROP_TMP_TABLE)" >> "$SHARED_DIR/logs/import-shapefile.log"


