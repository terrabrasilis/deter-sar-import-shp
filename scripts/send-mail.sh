#!/bin/bash

BODY="$1"

# if email control is enable
if [ $EMAIL_CTRL = true ]; then

TO=$(cat "$SHARED_DIR"/mail_to.cfg )
TMP_BODY=`echo "Subject: ${SUBJECT}"; cat ${BODY}`
echo "${TMP_BODY}" > ${BODY}

ssmtp -F'TerraBrasilis' -vvv ${TO} < ${BODY}

else
  echo "------------- email content start --------------"
  echo $(cat $BODY)
  echo "------------- email content end --------------"
fi