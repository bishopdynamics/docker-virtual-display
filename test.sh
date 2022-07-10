#!/usr/bin/env bash

# test the container. 
#   if you pass an argument, it will pass that to entrypoint.sh
#   ex: ./test.sh /usr/bin/xeyes

IMAGE_NAME="bishopdynamics/docker_virtual_display:latest"

TIMEZONE="America/Los Angeles"

# ./build.sh || {
#     echo "failed to build, cannot test!"
#     exit 1
# }

TEMP_DIR=$(mktemp -d)

if [ -z "$1" ]; then
    # no arguments, run the entrypoint from the container
    docker run -it \
    -e PUID=1000 \
    -e PGID=1000 \
    -e TZ="$TIMEZONE" \
    -p 5901:5900 \
    -v "${TEMP_DIR}":/config \
    "$IMAGE_NAME"
else
    # have args, override entrypoint to use them
    docker run -it \
    -e PUID=1000 \
    -e PGID=1000 \
    -e TZ="$TIMEZONE" \
    -p 5901:5900 \
    -v "${TEMP_DIR}":/config \
    --entrypoint "/entrypoint.sh" "$IMAGE_NAME" "$@"  # pass our arguments after image name
fi

rm -r "$TEMP_DIR"