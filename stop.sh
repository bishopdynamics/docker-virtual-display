#!/usr/bin/env bash

# stop anything we ran using deploy earlier

docker-compose stop && docker-compose rm -f && exit 0
exit 1
