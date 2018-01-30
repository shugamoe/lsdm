#!/bin/bash

while getopts u:s: option
do
    case "${option}" 
    in
    u) USER=${OPTARG};;
    s) SLAVES=${OPTARG};;
    esac
done

aws emr create-cluster --release-label emr-5.11.1 \
    --name "LSDM HW SETUP" \
    --instance-groups \
    InstanceGroupType=MASTER,InstanceCount=1,InstanceType=m4.large \
    InstanceGroupType=CORE,InstanceCount=2,InstanceType=m4.large \
    --applications Name=Spark Name=Ganglia \
    --ec2-attributes KeyName=jcm_lsdm,EmrManagedMasterSecurityGroup=sg-1cb87877,EmrManagedSlaveSecurityGroup=sg-1cb87877,SubnetId=subnet-872c8bef \
    --bootstrap-action Name="JCM stuff",Path="s3://jcm.lsdm/bootstrap/bootstrap_cluster_internet.sh" \
    --enable-debugging --log-uri "s3://jcm.lsdm/logs" \
    --no-verify-ssl --no-auto-terminate

# --configurations file://emr_config.json \
# Name='Install Jupyter notebook',Path="s3://aws-bigdata-blog/artifacts/aws-blog-emr-jupyter/install-jupyter-emr5.sh",Args=[--python3,--toree,--torch,,--ds-packages,--ml-packages,--python-packages,'ggplot nilearn',--port,8880,--password,jupyter,--jupyterhub,--jupyterhub-port,8001,--cached-install,--notebook-dir,s3://jcm.lsdm/notebooks/,--copy-samples] \
export CID=`aws emr list-clusters --no-verify-ssl | head -10 | grep "Id" | awk -F"\"" '{print $4}'`
