#!/bin/bash
host=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=host=[^*])[^"]*')
port=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=port=[^*])[^"]*')
database=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=database=[^*])[^"]*')
user=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=user=[^*])[^"]*')
pass=$(cat $SHARED_DIR/pgconfig | grep -oP '(?<=password=[^*])[^"]*')
DATE_LOG=$(date +"%Y-%m-%d_%H:%M:%S")

PG_BIN="/usr/bin"
PG_CON="-d $database -p $port -h $host"

OUTPUT_FINAL_TABLE="deter_sar_1ha"
OUTPUT_SOURCE_TABLE="$1"

# new index to improve diff
CREATE_INDEX="""
CREATE INDEX ${OUTPUT_SOURCE_TABLE}_idx_geom
    ON public.$OUTPUT_SOURCE_TABLE USING gist
    (geometries)
    TABLESPACE pg_default;
"""
# to process the difference between new SAR data and the production FM data
CREATE_TABLE="""
CREATE TABLE public.deter_sar_without_overlap AS
  SELECT gid as origin_gid, n_alerts, daydetec, area_ha, label, prob_max,
  (st_dump(
  COALESCE(
    safe_diff(a.geometries,
      (SELECT st_union(st_buffer(b.geom,0.000000001))
       FROM public.deter b
       WHERE
        b.source='M'
	      AND b.classname IN ('DESMATAMENTO_VEG','DESMATAMENTO_CR','MINERACAO')
        AND (a.geometries && b.geom)
     )
    ),
  a.geometries))).geom AS geom
FROM public.$OUTPUT_SOURCE_TABLE a;
"""

COPY_TO_FINAL_TABLE="""
INSERT INTO public.$OUTPUT_FINAL_TABLE
(geometries, n_alerts, daydetec, area_ha, label, prob_max)
SELECT ST_Multi(geom) as geometries,
n_alerts, daydetec, area_ha, label, prob_max
FROM public.deter_sar_without_overlap;
"""

DROP_SOURCE_TABLE="DROP TABLE $OUTPUT_SOURCE_TABLE"
DROP_TMP_TABLE="DROP TABLE public.deter_sar_without_overlap"

# create index to improve diff process 
$PG_BIN/psql $PG_CON -t -c "$CREATE_INDEX"
# create the intermeriary table for SAR without overlap
$PG_BIN/psql $PG_CON -t -c "$CREATE_TABLE"
# copy SAR data to output table
$PG_BIN/psql $PG_CON -t -c "$COPY_TO_FINAL_TABLE"
echo "$DATE_LOG - Copy SAR data to $OUTPUT_FINAL_TABLE" >> "$SHARED_DIR/logs/import-shapefile.log"

# drop the table data from source and intermediaries
$PG_BIN/psql $PG_CON -t -c "$DROP_SOURCE_TABLE"
$PG_BIN/psql $PG_CON -t -c "$DROP_TMP_TABLE"
echo "$DATE_LOG - Drop intermediary tables" >> "$SHARED_DIR/logs/import-shapefile.log"


