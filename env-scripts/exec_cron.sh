#!/bin/bash
# set env vars to use inside script
source /etc/environment
cd $INSTALL_PATH/scripts-shell
. ./import_to_database.sh
