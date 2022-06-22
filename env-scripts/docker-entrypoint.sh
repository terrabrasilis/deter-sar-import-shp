#!/bin/bash
echo "export SUBJECT=\"${SUBJECT}\"" >> /etc/environment
# run cron in foreground
cron -f