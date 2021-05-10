#!/bin/bash

# if email control is enable
if [ $EMAIL_CTRL = true ]; then

TO=$(cat "$SHARED_DIR"/mail_to.cfg )
BODY="$1"
(cat - $BODY)<<HEADERS_END | /usr/sbin/sendmail -F "TerraBrasilis" -i $TO
Subject: [DETER-R] - Log de importacao de dados para validacao
From: "terrabrasilis@inpe.br"
To: $TO

HEADERS_END

else
  echo "------------- email content start --------------"
  echo "$BODY"
  echo "------------- email content end --------------"
fi