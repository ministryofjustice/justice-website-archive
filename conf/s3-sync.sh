#!/bin/bash

/usr/local/bin/aws s3 sync /archiver/snapshots s3://"$(cat /archiver/.aws/s3-bucket)"

exit 0;
