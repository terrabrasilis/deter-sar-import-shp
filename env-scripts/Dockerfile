# To build image for this dockerfile use this command:
#   docker build -t terrabrasilis/daily-deter-for-ibama:vx.y -f env-scripts/Dockerfile --no-cache .
#
# To run without compose and without shell terminal use this command:
#   docker run -d --rm --name terrabrasilis_deter_scripts terrabrasilis/daily-deter-for-ibama:vx.y
#   docker run -d --rm --name terrabrasilis_deter_scripts -v $PWD:/data/files terrabrasilis/daily-deter-for-ibama:vx.y
#
#--------- Generic stuff all our Dockerfiles should start with so we get caching ------------
FROM ubuntu:18.04

LABEL "br.inpe.dpi"="INPE/DPI-TerraBrasilis" \
br.inpe.dpi.terrabrasilis="script-tasks" \
author="Andre Carvalho" \
author.email="andre.carvalho@inpe.br" \
description="Scripts for importing geographic data files from disk to the database table in PostGIS."
#-------------Application Specific Stuff ----------------------------------------------------

RUN apt-get -o Acquire::ForceIPv4=true update \
    && apt-get install -y \
    cron \
    tzdata \
    bash \
    wget \
    gnupg \
    unzip \
    ssmtp \
    curl \
    gdal-bin

RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
    && echo "deb http://apt.postgresql.org/pub/repos/apt/ bionic-pgdg main" > /etc/apt/sources.list.d/pgdg.list

RUN apt-get -o Acquire::ForceIPv4=true update \
      && apt-get install -y --no-install-recommends \
           postgresql-10-postgis-2.5 \
           postgis \
      && rm -rf /var/lib/apt/lists/*

# define the timezone to run cron
ENV TZ=America/Sao_Paulo
ENV SUBJECT="[DETER-R] Data Import Report"

# define the install path env var
ENV INSTALL_PATH /usr/local
ENV SHARED_DIR /data/files
ENV INPUT_DIR /input/files

## THE ENV VARS ARE NOT READED INSIDE A SHELL SCRIPT THAT RUNS IN CRON TASKS.
## SO, WE WRITE INSIDE THE /etc/environment FILE AND READS BEFORE RUN THE SCRIPT.
RUN echo "export SHARED_DIR=\"${SHARED_DIR}\"" >> /etc/environment \
    && echo "export INSTALL_PATH=\"${INSTALL_PATH}\"" >> /etc/environment \
    && echo "export INPUT_DIR=\"${INPUT_DIR}\"" >> /etc/environment \
    && echo "export EMAIL_CTRL=true" >> /etc/environment \
    && echo "export TZ=America/Sao_Paulo" >> /etc/environment

# INSTALL SCRIPTS
# ------------------------------------------------------
RUN mkdir -p $INSTALL_PATH/scripts-shell/
COPY scripts/ $INSTALL_PATH/scripts-shell/
RUN chmod +x $INSTALL_PATH/scripts-shell/*.sh

# install and enable cron job scripts
ADD env-scripts/exec_cron.sh $INSTALL_PATH/
RUN chmod +x $INSTALL_PATH/*.sh
# install and enable config cron
# for task
ADD env-scripts/schedule.cron /etc/cron.d/schedule-cron
RUN chmod 0644 /etc/cron.d/schedule-cron \
    && crontab /etc/cron.d/schedule-cron

# logs to output cron exec
RUN mkdir -p ${SHARED_DIR} \
    && mkdir /logs \
    && touch /logs/exec_cron_deter_sar.log

# Entry point to start the main docker job
ADD env-scripts/docker-entrypoint.sh $INSTALL_PATH/bin/docker-entrypoint.sh
RUN chmod +x $INSTALL_PATH/bin/*.sh \
    && ln -s usr/local/bin/docker-entrypoint.sh / # backwards compat

# expose shared dirs
VOLUME ["${SHARED_DIR}", "${INPUT_DIR}", "/logs"]

ENTRYPOINT [ "/docker-entrypoint.sh" ]