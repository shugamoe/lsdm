#!/bin/bash

aws emr create-cluster --release-label emr-5.11.1 \
    --instance-groups \
    InstanceGroupType=MASTER,InstanceCount=1,InstanceType=m4.large \
    InstanceGroupType=CORE,InstanceCount=2,InstanceType=m4.large \
    --applications Name=Spark Name=Ganglia \
    --ec2-attributes KeyName=jcm_lsdm,EmrManagedMasterSecurityGroup=sg-1cb87877,EmrManagedSlaveSecurityGroup=sg-1cb87877,SubnetId=subnet-872c8bef \
    --auto-terminate --no-verify-ssl
