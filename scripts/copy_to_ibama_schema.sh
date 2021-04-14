#!/bin/bash
host=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=host=[^*])[^"]*')
port=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=port=[^*])[^"]*')
database=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=database=[^*])[^"]*')

DATE_LOG=$(date +"%Y-%m-%d_%H:%M:%S")

PG_BIN="/usr/bin"
PG_CON="-d $database -p $port -h $host"

SCHEMA="deter_agregate"
OUTPUT_FINAL_TABLE="deter_sar_1ha"
OUTPUT_SOURCE_TABLE="$1"

# new index to improve diff
CREATE_INDEX="""
CREATE INDEX ${OUTPUT_SOURCE_TABLE}_idx_geom
    ON $SCHEMA.$OUTPUT_SOURCE_TABLE USING gist
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
       FROM public.deter b
       WHERE
        b.source='D'
	      AND b.classname IN ('DESMATAMENTO_VEG','DESMATAMENTO_CR','MINERACAO')
        AND (a.geometries && b.geom)
     )
    ),
  a.geometries))).geom AS geom
FROM $SCHEMA.$OUTPUT_SOURCE_TABLE a
WHERE a.class='CLEAR_CUT';
"""

UPDATE_AREA="""
UPDATE $SCHEMA.deter_sar_without_overlap SET area_ha=ST_area(a.geom::geography)/10000;
"""

# the 50 candidates by bigger areas
LIMIT="50"
CANDIDATES_BY_AREA="""
WITH candidates_by_area AS (
  SELECT ST_Multi(geom) as geometries,
  n_alerts, daydetec, area_ha, label, class, 1 as auditar
  FROM $SCHEMA.deter_sar_without_overlap
  ORDER BY area_ha DESC
  LIMIT $LIMIT
) INSERT INTO $SCHEMA.$OUTPUT_FINAL_TABLE
(geometries, n_alerts, daydetec, area_ha, label, class, auditar)
SELECT geometries, n_alerts, daydetec, area_ha, label, class, auditar FROM candidates_by_area
"""

# remove from temporary table
REMOVE_CANDIDATES_BY_AREA="""
WITH candidates_by_area AS (
  SELECT gid, area_ha
  FROM $SCHEMA.deter_sar_without_overlap
  ORDER BY area_ha DESC
  LIMIT $LIMIT
) DELETE FROM $SCHEMA.deter_sar_without_overlap
WHERE gid IN (SELECT gid FROM candidates_by_area)
"""

# the 150 candidates by random
LIMIT="150"
CANDIDATES_BY_RANDOM="""
WITH candidates_by_random AS (
  SELECT ST_Multi(geom) as geometries,
  n_alerts, daydetec, area_ha, label, class, 1 as auditar
  FROM $SCHEMA.deter_sar_without_overlap
  ORDER BY random()
  LIMIT $LIMIT
) INSERT INTO $SCHEMA.$OUTPUT_FINAL_TABLE
(geometries, n_alerts, daydetec, area_ha, label, class, auditar)
SELECT geometries, n_alerts, daydetec, area_ha, label, class, auditar
FROM candidates_by_random
"""

DROP_TMP_TABLE="DROP TABLE $SCHEMA.deter_sar_without_overlap"

# create index to improve diff process 
$PG_BIN/psql $PG_CON -t -c "$CREATE_INDEX"
# create the intermeriary table for SAR without overlap
$PG_BIN/psql $PG_CON -t -c "$CREATE_TABLE"
# update area
$PG_BIN/psql $PG_CON -t -c "$UPDATE_AREA"

# copy SAR data to output table (the first 50 candidates)
$PG_BIN/psql $PG_CON -t -c "$CANDIDATES_BY_AREA"
echo "$DATE_LOG - Copy the first 50 candidates from the SAR data to $OUTPUT_FINAL_TABLE" >> "$SHARED_DIR/logs/import-shapefile.log"

# remove some data based on 50 candidates
$PG_BIN/psql $PG_CON -t -c "$REMOVE_CANDIDATES_BY_AREA"
echo "$DATE_LOG - Remove the 50 candidates from intermediary table" >> "$SHARED_DIR/logs/import-shapefile.log"

# copy SAR data to output table (the random 150 candidates)
$PG_BIN/psql $PG_CON -t -c "$CANDIDATES_BY_RANDOM"
echo "$DATE_LOG - Copy the random 150 candidates from the SAR data to $OUTPUT_FINAL_TABLE" >> "$SHARED_DIR/logs/import-shapefile.log"

# drop the intermediary table
$PG_BIN/psql $PG_CON -t -c "$DROP_TMP_TABLE"
echo "$DATE_LOG - Drop intermediary tables ($DROP_TMP_TABLE)" >> "$SHARED_DIR/logs/import-shapefile.log"


