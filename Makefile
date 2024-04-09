## This is an example makefile created to demonstrate how to create and use targets as part of the ETL process.
## extract, transform, load (ETL) is a three-phase process where data is extracted, transformed (cleaned, sanitized, scrubbed)
## and loaded into an output data container
## -------------- EXPORT BLOCK ------------------------

# configuration file
file := ${GEOCINT_WORK_DIRECTORY}/config.inc.sh
# Add an export here for each variable from the configuration file that you are going to use in the targets.
export SLACK_CHANNEL = $(shell sed -n -e '/^SLACK_CHANNEL/p' ${file} | cut -d "=" -f 2)
export SLACK_BOT_NAME = $(shell sed -n -e '/^SLACK_BOT_NAME/p' ${file} | cut -d "=" -f 2)
export SLACK_BOT_EMOJI = $(shell sed -n -e '/^SLACK_BOT_EMOJI/p' ${file} | cut -d "=" -f 2)
export SLACK_KEY = $(shell sed -n -e '/^SLACK_KEY/p' ${file} | cut -d "=" -f 2)
export PGDATABASE = $(shell sed -n -e '/^PGDATABASE/p' ${file} | cut -d "=" -f 2)

# these makefiles are stored in geocint-runner and geocint-openstreetmap repositories
# runner_make contains the basic set of targets for creating the project folder structure
# osm_make contains a set of targets for osm data processing
include runner_make osm_make

## ------------- CONTROL BLOCK -------------------------

# you can replace dev with the names of the final targets, that you will use to run the pipeline if you don't need all of them
# you can also add here the names of targets that should not be rebuilt automatically, just when conditions are met or at your request
# to do it just add these names after the colon separated by a space
all: dev ## [FINAL] Meta-target on top of all other targets, or targets on parking.

# by default the clean target is set to serve an update of the OpenStreetMap planet dump during every run
clean: ## [FINAL] Cleans the worktree for the next nightly run. Does not clean non-repeating targets.
	if [ -f data/planet-is-broken ]; then rm -rf data/planet-latest.osm.pbf ; fi
	rm -rf data/planet-is-broken
	profile_make_clean data/planet-latest-updated.osm.pbf

## --------------- SAMPLE TARGET CHAIN ------------------

## --------------- PREPARATION STEP ---------------------
data/in/kontur_population: | data/in ## create folder to store kontur population
	mkdir -p $@

data/mid/kontur_population: | data/mid ## create forder to store unzipped kontur population
	mkdir -p $@
	
data/in/intensity: | data/in ## create folder to store file with intensity polygons
	mkdir -p $@
	
data/out/hex_intensity: | data/out ## create folder to store output data
	mkdir -p $@
		
## --------------- DOWNLOAD DATA ------------------------
	
data/in/intensity/intensity.geojson: | data/in/intensity ## download data with intensity polygons
	wget https://www.gdacs.org/datareport/resources/EQ/1357372/smpreliminary_1357372_1487096_0.geojson -O $@
		
data/in/kontur_population/Turkey.gpkg.gz: | data/in/kontur_population ## download population data for Turkey
	wget https://geodata-eu-central-1-kontur-public.s3.amazonaws.com/kontur_datasets/kontur_population_TR_20220630.gpkg.gz -O $@
		
data/in/kontur_population/Syria.gpkg.gz: | data/in/kontur_population ## download population data for Syria
	wget https://geodata-eu-central-1-kontur-public.s3.amazonaws.com/kontur_datasets/kontur_population_SY_20220630.gpkg.gz -O $@

## --------- LOAD DATA TO DATABASE AND PROCESS ----------	

data/mid/unzip_pop: data/in/kontur_population/Turkey.gpkg.gz data/in/kontur_population/Syria.gpkg.gz | data/mid/kontur_population ## unzip kontur population data
	find data/in/kontur_population -name "*.gpkg.gz" | parallel "gzip -dk {}"
	find data/in/kontur_population -name "*.gpkg" | parallel "mv {} data/mid/kontur_population/"
	find data/in/kontur_population -name "*.gpkg" | parallel "rm -f {}"
	touch $@
	
db/table/population: data/mid/unzip_pop | db/table ## create table and load data
	psql -c "drop table if exists population_in;"
	find data/mid/kontur_population -name "*.gpkg" | parallel "ogr2ogr --config PG_USE_COPY YES -f PostgreSQL PG:'dbname= ${PGDATABASE}' {} -t_srs EPSG:4326 -nln population_in -lco GEOMETRY_NAME=geom"
	psql -c "drop table if exists population;"
	psql -c "select distinct on (h3) * into population from population_in;"
	psql -c "drop table if exists population_in;"
	touch $@
	
db/table/intensity: data/in/intensity/intensity.geojson | db/table ## load data with intensity
	psql -c "drop table if exists intensity_in;"
	ogr2ogr -f PostgreSQL PG:"dbname=${PGDATABASE}" data/in/intensity/intensity.geojson -nln intensity_in
	psql -c "delete from intensity_in where value < 5;"
	psql -c "drop table if exists intensity_mid;"
	psql -c "select value, units, (ST_Dump(wkb_geometry)).geom geom into intensity_mid from intensity_in;"
	psql -c "drop table if exists intensity;"
	psql -c "select value, units, ST_makepolygon(geom) geom into intensity from intensity_mid where ST_numpoints(geom) >= 4 ;"
	touch $@
	
db/table/hex_intensity: db/table/population db/table/intensity | db/table ## add intensity value to hexagons
	psql -c "drop table if exists intersection;"
	psql -c "select p.*, i.value, i.units into intersection from population p, intensity i where ST_Intersects(p.geom, i.geom);"
	psql -c "drop table if exists hex_intensity;"
	psql -c "select h3 h3idx, max(value) value, population, geom, units, ST_x(h3_cell_to_geometry(h3::h3index)) lon, ST_y(h3_cell_to_geometry(h3::h3index)) lat into hex_intensity from intersection group by h3, units, population, geom;"
	touch $@

## ------- EXTRACT DATA TO GEOJSON FILE AND BUILD MAP -----

# extract data to geojson file
data/out/hex_intensity/intensity.geojson: db/table/hex_intensity | data/out/hex_intensity ## Export to GEOJSON hexes with population and intensity
	rm -f $@
	ogr2ogr -f GeoJSON data/out/hex_intensity/intensity.geojson PG:"dbname= ${PGDATABASE}" -sql "select * from hex_intensity" -nln intensity

# build map	
data/out/hex_intensity/hex_intensity_map.html: data/out/hex_intensity/intensity.geojson | data/out/hex_intensity 
	python scripts/3dmap.py data/out/hex_intensity/intensity.geojson $@
	

# A dev target is an example of a meta-target that depends on all chains of targets and allows you to run the entire pipeline with only one target running.
# Also, this target allows you to send messages to the slack channel in case the entire pipeline was successfully completed (or you can perform any other action)
dev: data/out/hex_intensity/hex_intensity_map.html ## Send a message about the successful execution of the pipeline
	#send dev target successfully build- message to a slack channel 
	echo "dev target successfully build" | python scripts/slack_message.py $$SLACK_CHANNEL ${SLACK_BOT_NAME} $$SLACK_BOT_EMOJI
	touch $@	
