#!/bin/bash
virtualenv --python=python3 env
source env/bin/activate
pip install -r requirements.txt
ansible-galaxy collection install linode.cloud community.crypto community.mysql
ansible-playbook provision.yml -vvv