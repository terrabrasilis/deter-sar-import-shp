# DETER SAR for Import Shapes

A basic service to read shapefiles from an input directory, unzip them and import them into a database table.

## Configuration

This service depends on a file called pgconfig. As an example of this configuration file, use pgconfig.example. The service expects to find the configuration file in the shared directory; see the environment setup session for more details.

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

### Exceptional context (period changes)

If we need to replace the default period, we must use the text file called overwrite_period inside the input directory, together the shapefiles and the contents of this file should be as shown below.

Content example to overwrite_period text file. Pay attention with double quotes to enclose the date.
```
start_date="2020-08-30"
end_date="2020-09-01"
```

 > The overwrite_period file will be renamed to overwrite_period.done after reading