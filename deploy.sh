#!/bin/bash
set -ex
trap "cleanup $? $LINENO" EXIT

# enable logging
#exec > >(tee /dev/ttyS0 /var/log/ansible.log) 2>&1

# source stackscript variables
#${TOKEN_PASSWORD} ${ROOT_PASS} ${SSH_KEYS} ${ADD_SSH_KEYS}
#source $HOME/StackScript

function cleanup {
  if [ "$?" != "0" ]; then
    echo "PLAYBOOK FAILED. See /var/log/ansible.log for details."
    deactivate
    rm -rf env
    exit 1
  fi
}

function run_playbook {
  # set up virtual environment
  #virtualenv --python=python3 env
  #source env/bin/activate
  
  # install requirements
  #pip install -r requirements.txt
  #ansible-galaxy collection install linode.cloud community.crypto community.mysql

  # write secret vars
  echo ${TOKEN_PASSWORD}
  echo ${ROOT_PASS}
  echo ${SSH_KEYS}
  echo $ADD_SSH_KEYS
  #TEMP_ROOT_PASS=$(openssl rand -base64 32)
  #ansible-vault encrypt_string "${TEMP_ROOT_PASS}" --name 'root_pass' > group_vars/galera/secret_vars
  #ansible-vault encrypt_string "${TOKEN_PASSWORD}" --name 'token' >> group_vars/galera/secret_vars

  # run provision playbook
  ansible-playbook provision.yml

  # run galera playbook
  #ansible-playbook -i hosts site.yml --extra-vars "root_password=${ROOT_PASS} account_ssh_keys=${SSH_KEYS} add_keys_prompt=${ADD_SSH_KEYS}""

  # deactivate virtual environment
  deactivate
  rm -rf env
}

# main
run_playbook
