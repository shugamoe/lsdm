#!/bin/bash

set -ex

# Jupyteret with create cluster
NOTEBOOK_DIR="s3://jcm.lsdm/notebooks/"
PORT=${1:-8194}
JUPYTER_PASSWORD=${2:-"p4ssword"}
	
# mount home to /mnt
if [ ! -d /mnt/home ]; then
  	  sudo mv /home/ /mnt/
  	  sudo ln -s /mnt/home /home
fi
	
# Install conda
wget https://repo.continuum.io/miniconda/Miniconda3-4.3.31-Linux-x86_64.sh -O /home/hadoop/miniconda.sh\
	&& /bin/bash ~/miniconda.sh -b -p $HOME/conda
echo "\nexport PATH=$HOME/conda/bin:$PATH" >> $HOME/.bashrc && source $HOME/.bashrc
conda config --set always_yes yes --set changeps1 no
	
# Install additional libraries for all instances with conda
conda install conda=4.3.31

conda config -f --add channels conda-forge
conda config -f --add channels defaults

conda install hdfs3 findspark ujson jsonschema toolz boto3 py4j numpy pandas

# cleanup
rm ~/miniconda.sh

echo bootstrap_conda.sh completed. PATH now: $PATH

# setup python 3.6 in the master and workers
export PYSPARK_PYTHON="/home/hadoop/conda/bin/python3.6"
sudo yum -y install python36
alias python=python3
pip install --user --upgrade pip
pip install --user jupyter
pip install --user pandas
pip install --user pyspark
echo "Python Libraries Installed"

echo 'Having Yum Update Things'
sudo yum -y update

# serve notebook from master node
IS_MASTER=false
if grep isMaster /mnt/var/lib/info/instance.json | grep true;
    then
        IS_MASTER=true
fi

if $IS_MASTER;
then
    # install dependencies for s3fs-fuse to access and store notebooks
    sudo yum install -y git
    sudo yum install -y libcurl libcurl-devel graphviz
    sudo yum install -y cyrus-sasl cyrus-sasl-devel readline readline-devel gnuplot
    sudo yum install -y automake

    # extract BUCKET and FOLDER to mount from NOTEBOOK_DIR
    NOTEBOOK_DIR="${NOTEBOOK_DIR%/}/"
    BUCKET=$(python -c "print('$NOTEBOOK_DIR'.split('//')[1].split('/')[0])")
    FOLDER=$(python -c "print('/'.join('$NOTEBOOK_DIR'.split('//')[1].split('/')[1:-1]))")

    # install s3fs
    cd /mnt
    git clone https://github.com/s3fs-fuse/s3fs-fuse.git
    cd s3fs-fuse/
    ls -alrt
    ./autogen.sh
    ./configure
    make
    sudo make install
    sudo su -c 'echo user_allow_other >> /etc/fuse.conf'
    mkdir -p /mnt/s3fs-cache
    mkdir -p /mnt/$BUCKET
    /usr/local/bin/s3fs -o allow_other -o iam_role=auto -o umask=0 -o url=https://s3.amazonaws.com  -o no_check_certificate -o enable_noobj_cache -o use_cache=/mnt/s3fs-cache $BUCKET /mnt/$BUCKET

    # Install Jupyter Note book on master and libraries
    conda install jupyter
    conda install matplotlib plotly bokeh
    conda install --channel scikit-learn-contrib scikit-learn==0.18

    # jupyter configs
    mkdir -p ~/.jupyter
    touch ls ~/.jupyter/jupyter_notebook_config.py
    HASHED_PASSWORD=$(python -c "from notebook.auth import passwd; print(passwd('$JUPYTER_PASSWORD'))")
    echo "c.NotebookApp.password = u'$HASHED_PASSWORD'" >> ~/.jupyter/jupyter_notebook_config.py
    echo "c.NotebookApp.open_browser = False" >> ~/.jupyter/jupyter_notebook_config.py
    echo "c.NotebookApp.ip = '*'" >> ~/.jupyter/jupyter_notebook_config.py
    echo "c.NotebookApp.notebook_dir = '/mnt/$BUCKET/$FOLDER'" >> ~/.jupyter/jupyter_notebook_config.py
    echo "c.ContentsManager.checkpoints_kwargs = {'root_dir': '.checkpoints'}" >> ~/.jupyter/jupyter_notebook_config.py
    echo "c.NotebookApp.port = $PORT" >> ~/.jupyter/jupyter_notebook_config.py
    echo "c.NotebookApp.shutdown_no_activity = 10" >> ~/.jupyter/jupyter_notebook_config.py

# If on master then start up jupyter daemon (Uses Upstart)
cd ~
sudo cat << EOF > /home/hadoop/jupyter.conf
description "Jupyter"
author      "Julian modified from https://bytes.babbel.com/en/articles/2017-07-04-spark-with-jupyter-inside-vpc.html"

start on runlevel [2345]
stop on runlevel [016]

respawn
respawn limit 0 10

chdir /mnt/$BUCKET/$FOLDER
	
script
  		sudo su - hadoop > /var/log/jupyter.log 2>&1 << BASH_SCRIPT
    export PYSPARK_DRIVER_PYTHON="/home/hadoop/conda/bin/jupyter"
    export PYSPARK_DRIVER_PYTHON_OPTS="notebook --log-level=INFO"
    export PYSPARK_PYTHON=/home/hadoop/conda/bin/python3.6
    export JAVA_HOME="/etc/alternatives/jre"
    pyspark
        BASH_SCRIPT

end script
EOF
sudo mv /home/hadoop/jupyter.conf /etc/init/
sudo chown root:root /etc/init/jupyter.conf
 
# be sure that jupyter daemon is registered in initctl
sudo initctl reload-configuration
 
# start jupyter daemon
sudo initctl start jupyter
fi
