#!/bin/bash
exec > /dev/ttyS0 2>&1

virtualenv --python=python3 env
source env/bin/activate
pip install -r requirements.txt
ansible-galaxy collection install linode.cloud community.crypto community.mysql

# make secrets
TEMP_ROOT_PASS=$(openssl rand -base64 32)
ansible-vault encrypt_string ${TEMP_ROOT_PASS} --name 'root_pass' > group_vars/galera/secret_vars
ansible-vault encrypt_string $1 --name 'token' >> group_vars/galera/secret_vars

# run  playbook
ansible-playbook provision.yml -vvv