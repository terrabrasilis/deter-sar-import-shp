# The tasks - Shell Scripts for SHP generation

There are two tasks here. A task to generate Shapefiles every day and another to upload the shapefile to FTP.

The scripts used here, depends of the environment variables but when this scripts runs inside a task based in crontab the environment variables was unreachable.
So we use one technique that consist to write the environment variables inside a file and read that file when the scripts triggered by cron. See in the Dockerfile the session where we writing the /etc/environment.

The entry point is start_process.sh

## Base configuration

The allow configuration is:
- the hour for the cron job (use the daily.cron file)*;
- the options for FTP (set in secrets of Docker Swarm as below)**;
- the options for Postgres (set in secrets of Docker Swarm as below)**;

```yaml
# for example
echo "user_name" |docker secret create postgres.user.fm -
echo "user_pass" |docker secret create postgres.pass.fm -
echo "user_name" |docker secret create ftp.user.censipam -
echo "user_pass" |docker secret create ftp.pass.censipam -
```

*Needs rebuild Docker Image

**Needs container update

## Build the docker

To build image for this dockerfile use this command:

```bash
docker build -t terrabrasilis/daily-deter-for-ibama:<version> -f env-scripts/Dockerfile --no-cache .
# or use the build script
./docker-build.sh
```

## Run on docker (dev)

To run locally in dev environment, change the Dockerfile including the RUN command to create secret files for simulate the docker secrets outside Swarm.

Example for simulate Docker Secrets.
```yaml
RUN echo "ftp_user" > /run/secrets/ftp.user.censipam \
    && echo "secret_for_ftp" > /run/secrets/ftp.pass.censipam \
    && echo "postgres_user" > /run/secrets/postgres.user.fm \
    && echo "secret_for_postgres" > /run/secrets/postgres.pass.fm
```

```bash
docker run -d --rm --name terrabrasilis_deter_scripts terrabrasilis/daily-deter-for-ibama:<version>
```

### To login inside container

```bash
docker container exec -it <container_id_or_name> sh
```

## Run on stack

For run this service on Swarm use the [data-service-auth.yaml](https://github.com/Terrabrasilis/docker-stacks/blob/master/deter-sync/data-service-auth.yaml).

Preconditions:
- Create the directory into the file system of the docker manager node for persist the Shapefile files;
- Edit the data-service-auth.yaml to point the working directory created above;
- Create the secrets into docker manager node to store the user names and passwords for FTP and postgres used by the scripts in client mode;
- Edit the data-service-auth.yaml to inform the name of the docker secret for FTP and postgres if is needed*;

*The dockerfile expect the Docker Secrets as follows: postgres.host.fm, postgres.port.fm, postgres.user.fm, postgres.pass.fm, postgres.db.fm, postgres.schema.fm, postgres.table.fm, ftp.user.censipam, ftp.pass.censipam, ftp.host.censipam, ftp.path.censipam
