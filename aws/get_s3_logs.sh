#!/bin/bash

rm -r ~/lsdm/aws/logs/
aws s3 cp --recursive s3://jcm.lsdm/logs ~/lsdm/aws/logs --no-verify-ssl
gunzip -r ~/lsdm/aws/logs
