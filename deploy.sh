#!/bin/bash
set -e
trap "cleanup $? $LINENO" EXIT

function cleanup {
  if [ "$?" != "0" ]; then
    echo "PLAYBOOK FAILED. See /var/log/stackscript.log for details."
    exit 1
  fi
}

function run_playbook {
  # run provision playbook
  #echo "private_key_file = $HOME/.ssh/id_ansible_ed2551" >> ansible.cfg
  ansible-playbook provision.yml --extra-vars "localhost_public_ip=${PUBLIC_IP} localhost_private_ip=${PRIVATE_IP}" --flush-cache
  # run galera playbook
  ansible-playbook -i hosts site.yml --extra-vars "root_password=${ROOT_PASS} account_ssh_keys=${SSH_KEYS} add_keys_prompt=${ADD_SSH_KEYS}" -vvv
}

# main
run_playbook
