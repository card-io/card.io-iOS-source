#!/bin/bash

source /usr/local/bin/virtualenvwrapper.sh
mkvirtualenv cardio
pip install -r pip_requirements.txt
touch .baler_env
echo 'export PATH=$PATH:~/.virtualenvs/cardio/bin' > .baler_env
git tag -a iOS_$VERSION -m iOS_$VERSION
fab build:outdir=.