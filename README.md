## ASD-geocint
This is an example makefile created to demonstrate how to create and use targets as part of the ETL process using Geocint.
extract, transform, load (ETL) is a three-phase process where data is extracted, transformed (cleaned, sanitized, scrubbed) and loaded into an output data container.


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

<iframe
  src="hex_intensity_map.html"
  style="width:100%; height:300px;"
></iframe>
