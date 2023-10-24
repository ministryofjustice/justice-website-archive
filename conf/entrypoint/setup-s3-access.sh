#!/bin/bash

mkdir -p /archiver/.aws

echo "$S3_BUCKET_NAME" > /archiver/.aws/s3-bucket
