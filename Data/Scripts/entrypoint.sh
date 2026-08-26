#!/bin/bash


set -e
service ssh start
service cron start

tail -f /dev/null