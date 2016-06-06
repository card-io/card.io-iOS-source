#!/bin/bash

# to make virtualenvwrapper to work . different people are keeping this file on different placess 
source /usr/local/bin/virtualenvwrapper.sh
source /opt/local/Library/Frameworks/Python.framework/Versions/2.7/bin/virtualenvwrapper.sh

#build commands 
mkvirtualenv cardio
pip install -r pip_requirements.txt
touch .baler_env
echo 'export PATH=$PATH:~/.virtualenvs/cardio/bin' > .baler_env
git tag -a iOS_$VERSION -m iOS_$VERSION
fab build:outdir=.
