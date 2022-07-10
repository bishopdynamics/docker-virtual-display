#!/usr/bin/env bash

# (re-)deploy the compose file

./stop.sh && docker-compose up -d