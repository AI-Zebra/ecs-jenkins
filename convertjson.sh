#!/bin/sh
cat ./ecs/container-definition-update-image.json | sed '1d; $d'  > 9.json
/usr/bin/spruce merge 9.json 3.json | spruce json > 5.json | cat 5.json
