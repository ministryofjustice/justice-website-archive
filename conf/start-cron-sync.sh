#!/bin/bash
## Resides in the cron directory
## This schedule will only start and end with a mirror process
nohup supercronic -split-logs /etc/cron.d/process-sync 1>/archiver/supercronic_sync.log &
echo $! > /archiver/supercronic_sync.pid
