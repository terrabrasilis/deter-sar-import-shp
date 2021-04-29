#!/bin/bash
DATE_LOG=$(date +%Y-%m-%d)
LOGFILE="import_shapefile_$DATE_LOG.log"

TO=$(cat "$SHARED_DIR"/mail_to.cfg )
BODY="$SHARED_DIR/logs/$LOGFILE"
(cat - $BODY)<<HEADERS_END | /usr/sbin/sendmail -F "TerraBrasilis" -i $TO
Subject: [DETER-R] - Log de importação de dados para validação
To: $TO

HEADERS_END