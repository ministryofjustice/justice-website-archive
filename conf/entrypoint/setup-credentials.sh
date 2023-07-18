#!/bin/bash

mkdir -p /archiver/.aws
{
  echo "[default]"
  echo "aws_access_key_id = $S3_ACCESS_KEY_ID"
  echo "aws_secret_access_key = $S3_SECRET_ACCESS_KEY"
  echo ""
} > /archiver/.aws/credentials

echo "$S3_BUCKET_NAME" > /archiver/.aws/s3-bucket
