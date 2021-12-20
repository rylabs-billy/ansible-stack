#!/bin/bash
set -e
trap "cleanup $? $LINENO" EXIT

function cleanup {
  if [ "$?" != "0" ]; then
    echo "PLAYBOOK FAILED. See /var/log/stackscript.log for details."
    rm ${HOME}/.ssh/id_ansible_ed25519{,.pub}
    destroy
    exit 1
  fi
}

# global constants
readonly ROOT_PASS=$(cat /etc/shadow | grep root)
readonly LINODE_PARAMS=($(curl -sH "Authorization: Bearer ${TOKEN_PASSWORD}" "https://api.linode.com/v4/linode/instances/${LINODE_ID}" | jq -r .type,.region,.image,.label))
readonly TAGS=$(curl -sH "Authorization: Bearer ${TOKEN_PASSWORD}" "https://api.linode.com/v4/linode/instances/${LINODE_ID}" | jq -r .tags)
#readonly PUBLIC_IP=$(curl -sH "Authorization: Bearer ${TOKEN_PASSWORD}" "https://api.linode.com/v4/linode/instances/${LINODE_ID}" | jq -r .ipv4[0])
#readonly VARS_PATH="./group_vars/galera/vars"
#readonly SECRET_VARS_PATH="./group_vars/galera/secret_vars"

# utility functions
function destroy {
    ansible-playbook -i hosts destroy.yml
}

function secrets {
  local SECRET_VARS_PATH="./group_vars/galera/secret_vars"
  local VAULT_PASS=$(openssl rand -base64 32)
  local TEMP_ROOT_PASS=$(openssl rand -base64 32)
  echo "${VAULT_PASS}" > ./vault-pass
	ansible-vault encrypt_string "${TEMP_ROOT_PASS}" --name 'root_pass' > ${SECRET_VARS_PATH}
	ansible-vault encrypt_string "${TOKEN_PASSWORD}" --name 'token' >> ${SECRET_VARS_PATH}
}

function ssh_key {
    ssh-keygen -o -a 100 -t ed25519 -C "ansible" -f "${HOME}/.ssh/id_ansible_ed25519" -q -N "" <<<y >/dev/null
    export ANSIBLE_SSH_PUB_KEY=$(cat ${HOME}/.ssh/id_ansible_ed25519.pub)
    export ANSIBLE_SSH_PRIV_KEY=$(cat ${HOME}/.ssh/id_ansible_ed25519)
    local SSH_KEY_PATH="${HOME}/.ssh/id_ansible_ed25519"
    chmod 700 ${HOME}/.ssh
    chmod 600 ${SSH_KEY_PATH}
    eval $(ssh-agent)
    ssh-add ${SSH_KEY_PATH}
    echo -e "\nprivate_key_file = ${SSH_KEY_PATH}" >> ansible.cfg
}

# production
function ansible:build {
  secrets
  ssh_key
  # write vars file
  sed 's/  //g' <<EOF > group_vars/galera/vars
  # linode vars
  ssh_keys: ${ANSIBLE_SSH_PUB_KEY}
  galera_prefix: ${LINODE_PARAMS[3]}
  cluster_name: ${CLUSTER_NAME}
  type: ${LINODE_PARAMS[0]}
  region: ${LINODE_PARAMS[1]}
  image: ${LINODE_PARAMS[2]}
  group:
  linode_tags: ${TAGS}
  # ssl/tls vars
  country_name: ${COUNTRY_NAME}
  state_or_province_name: ${STATE_OR_PROVINCE}
  locality_name: ${LOCALITY_NAME}
  organization_name: ${ORGANIZATION_NAME}
  email_address: ${EMAIL_ADDRESS}
  ca_common_name: ${CA_COMMON_NAME}
  common_name: ${COMMON_NAME}
EOF
cat group_vars/galera/vars
}

function ansible:deploy {
  ansible-playbook provision.yml
  ansible-playbook -i hosts site.yml --extra-vars "root_password=${ROOT_PASS}  add_keys_prompt=${ADD_SSH_KEYS}"
}

# testing
function build {
    #curl -so ${VARS_PATH} ${VARS_URL}
	echo "${VAULT_PASS}" > ./vault-pass
	ansible-vault encrypt_string "${TEMP_ROOT_PASS}" --name 'root_pass' > ${SECRET_VARS_PATH}
	ansible-vault encrypt_string "${TOKEN_PASSWORD}" --name 'token' >> ${SECRET_VARS_PATH}
    
    # add ssh key
    #ssh-keygen -o -a 100 -t ed25519 -C "ansible" -f "${HOME}/.ssh/id_ansible_ed25519" -q -N "" <<<y >/dev/null
    #export ANSIBLE_SSH_PUB_KEY=$(cat ${HOME}/.ssh/id_ansible_ed25519.pub)
    #export ANSIBLE_SSH_PRIV_KEY=$(cat ${HOME}/.ssh/id_ansible_ed25519)
    chmod 700 ${HOME}/.ssh
    chmod 600 ${SSH_KEY_PATH}
    eval $(ssh-agent)
    ssh-add ${SSH_KEY_PATH}
    echo -e "\nprivate_key_file = ${SSH_KEY_PATH}" >> ansible.cfg
}



case $1 in
    #private_ip) "$@"; exit;;
    ansible:build) "$@"; exit;;
    ansible:deploy) "$@"; exit;;
    build) "$@"; exit;;
    env) "$@"; exit;;
esac

# main
#private_ip
ansible
build