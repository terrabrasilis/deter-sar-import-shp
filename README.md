# DETER SAR for Import Shapes

A basic service to read shapefiles from an input directory, unzip them and import them into a database table.

## Configuration

This service depends on a file called pgconfig. As an example of this configuration file, use pgconfig.example. The service expects to find the configuration file in the shared directory; see the environment Postgres setup session for more details.

### Postgres setup

Make sure there is a postgres configuration file pointing to the database where the data will be imported.

```sh
# pgconfig.example
user="postgres"
host="localhost"
port="5432"
database="deter_r"
password="postgres"
```

### Environment configuration

To run this container, use the docker-compose file.
```sh
# expect that docker-compose.yaml file exists and founded into current directory
docker-compose up -d
```

We must have the following volumes mounted on the container:

- SHARED_DIR (the working directory where we will put pgconfig)
- INPUT_DIR (the location of the input shp files)
- /logs (the location for the output log files)

Before running the container, verify that the mounted volumes exist as directories on the host machine.
