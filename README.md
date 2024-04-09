## ASD-geocint
This is an example makefile created to demonstrate how to create and use targets as part of the ETL process using Geocint.

Code in this repo allows you to generate 3d population map for [2023 Eartquake in Turkey and Syria](https://en.wikipedia.org/wiki/2023_Turkey%E2%80%93Syria_earthquakes) using [Kontur Population dataset](https://data.humdata.org/dataset/kontur-population-dataset?).


## Installation:

To install geocint on your Ubuntu server, use step-by-step installation guide from [installation guide](https://github.com/konturio/geocint-runner/DOCUMENTATION.md)

[geocint-runner](https://github.com/konturio/geocint-runner) – installation and documentation part

[geocint-openstreetmap](https://github.com/konturio/geocint-openstreetmap) – OSM related chain of targets

## How to run:

```
with make profiler:

profile_make -j -k data/out/hex_intensity/hex_intensity_map.html

just with make

make data/out/hex_intensity/hex_intensity_map.html
```

## Example:

[example html file with 3d population map](https://github.com/frolui/asd-geocint/blob/master/hex_intensity_map_example.html)
