#!/bin/bash
TO=$(cat "$SHARED_DIR"/mail_to.cfg )
BODY="$1"
(cat - $BODY)<<HEADERS_END | /usr/sbin/sendmail -F "TerraBrasilis" -i $TO
Subject: [DETER-R] - Log de importacao de dados para validacao
From: "TerraBrasilis<terrabrasilis@inpe.br>"
To: $TO

HEADERS_END