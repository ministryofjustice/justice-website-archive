#!/bin/bash

nohup supercronic -split-logs /etc/cron.d/process-mirror 1>/archiver/supercronic_mirror.log &

