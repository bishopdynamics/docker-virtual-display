#!/usr/bin/env bash

# build whatever is defined in docker-compose

docker-compose build || exit 1
exit 0
