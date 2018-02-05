#!/bin/bash

# Usage: source start_cluster.sh <num_slaves> <port_for_notebook> <notebook password>

NAME="LSDM HW SETUP"
SLAVES=${2:-2}
echo "Server name: $NAME"
echo "1 Master node, $SLAVES core nodes"

PORT_NUM=${2:-8194}
NOTEBOOK_PW=${3:-"p4ssword"}

echo "Jupyter notebook at port: $PORT_NUM"
echo "Password for notebook is: $NOTEBOOK_PW"
# Some spacing for the messy output below
echo ""
echo ""
echo ""

aws emr create-cluster --release-label emr-5.11.1 \
    --name $NAME \
    --instance-groups \
    InstanceGroupType=MASTER,InstanceCount=1,InstanceType=m4.large \
    InstanceGroupType=CORE,InstanceCount=$SLAVES,InstanceType=m4.large \
    --applications Name=Spark Name=Ganglia \
    --ec2-attributes KeyName=jcm_lsdm,EmrManagedMasterSecurityGroup=sg-1cb87877,EmrManagedSlaveSecurityGroup=sg-1cb87877,SubnetId=subnet-872c8bef \
    --bootstrap-action Path="s3://jcm.lsdm/bootstrap/bootstrap_cluster_final.sh",Args=$PORT_NUM,$NOTEBOOK_PW \
    --enable-debugging --log-uri "s3://jcm.lsdm/logs" \
    --no-verify-ssl --no-auto-terminate

export CID=`aws emr list-clusters --no-verify-ssl | head -10 | grep "Id" | awk -F"\"" '{print $4}'`
