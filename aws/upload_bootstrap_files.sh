#!/bin/bash

aws s3 cp jupyter_notebook_config.py s3://jcm.lsdm/bootstrap/ --no-verify-ssl
aws s3 cp bootstrap_cluster.sh s3://jcm.lsdm/bootstrap/ --no-verify-ssl
aws s3 cp bootstrap_cluster_internet.sh s3://jcm.lsdm/bootstrap/ --no-verify-ssl
aws s3 cp emr_config.json s3://jcm.lsdm/bootstrap/ --no-verify-ssl
