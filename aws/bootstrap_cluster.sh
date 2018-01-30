#!/bin/bash

set -ex

# Jupyter from Anaconda
# wget https://repo.continuum.io/archive/Anaconda3-5.0.1-Linux-x86_64.sh
# chmod 755 Anaconda3-5.0.1-Linux-x86_64.sh
# echo "Anaconda downloaded and permissions changed"


# echo "Installing Anaconda"
# ./Anaconda3-5.0.1-Linux-x86_64.sh -b # Batch mode for non-interactive
# echo 'export PATH="~/anaconda3/bin:$PATH"'

# source ~/.bashrc
# echo "Anaconda Installed"
# echo `which python`
# echo "Python should be from anaconda now"

# Jupyter from Pip
sudo yum -y install python36
alias python=python3
pip install --user --upgrade pip
pip install --user jupyter
pip install --user pandas
pip install --user pyspark
echo "Python Libraries Installed"

echo 'Having Yum Update Things'
sudo yum -y update

# Serve notebook from Master Node
IS_MASTER=false
if grep isMaster /mnt/var/lib/info/instance.json | grep true;
    then
        IS_MASTER=true
fi

if $IS_MASTER;
then
    mkdir ~/.jupyter
    cd ~/.jupyter
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:1024 -keyout mycert.pem -out mycert.pem
    mkdir ~/.jupyter
    cd ~/.jupyter
    aws s3 cp s3://jcm.lsdm/bootstrap/jupyter_notebook_config.py ./
    echo "Jupyter Notebook Config copied from S3"
    jupyter notebook &
    echo "Jupyter Notebook has run"
fi
