#!/bin/sh
cat ./ecs/container-definition-update-image.json | sed 's/^.\(.*\).$/\1/'  > 9.json
/usr/bin/spruce merge 9.json 3.json | spruce json > 5.json | cat 5.json
cat 5.json | sed  -i '1i /path/of/file.sh' > 10.json
cat 10.json | sed -e '$a]' > 11.json
