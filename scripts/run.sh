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
readonly ROOT_PASS=$(sudo cat /etc/shadow | grep root)
readonly LINODE_PARAMS=($(curl -sH "Authorization: Bearer ${TOKEN_PASSWORD}" "https://api.linode.com/v4/linode/instances/${LINODE_ID}" | jq -r .type,.region,.image,.label))
readonly TAGS=$(curl -sH "Authorization: Bearer ${TOKEN_PASSWORD}" "https://api.linode.com/v4/linode/instances/${LINODE_ID}" | jq -r .tags)
readonly VARS_PATH="./group_vars/galera/vars"

# utility functions
function destroy {
    ansible-playbook -i hosts destroy.yml ${1} ${2}
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
    export SSH_KEY_PATH="${HOME}/.ssh/id_ansible_ed25519"
    chmod 700 ${HOME}/.ssh
    chmod 600 ${SSH_KEY_PATH}
    eval $(ssh-agent)
    ssh-add ${SSH_KEY_PATH}
    echo -e "\nprivate_key_file = ${SSH_KEY_PATH}" >> ansible.cfg
}

function lint {
  yamllint .
  ansible-lint
  flake8
}

function verify {
    ansible-playbook -i hosts verify.yml
    destroy --extra-vars "galera_prefix=${DISTRO}_${DATE}"
}

# production
function ansible:build {
  #local VARS_PATH="./group_vars/galera/vars"
  secrets
  ssh_key
  # write vars file
  sed 's/  //g' <<EOF > ${VARS_PATH}
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
}

function ansible:deploy {
  ansible-playbook provision.yml
  ansible-playbook -i hosts site.yml --extra-vars "root_password=${ROOT_PASS}  add_keys_prompt=${ADD_SSH_KEYS}"
}

# testing
function test:build {
  echo "The vars URL is: ${VARS_URL}"
  curl -so ${VARS_PATH} ${VARS_URL}
  cat "./group_vars/galera/vars" # new
  secrets
  ssh_key
}

function test:deploy {
  local DISTRO="${1}"
  #local distro=$(echo ${image} | awk -F / '{print $2}')
  local DATE="$(date '+%Y-%m-%d_%H%M%S')"
  echo "the ssh key is: ${ANSIBLE_SSH_PUB_KEY}"
  ansible-playbook provision.yml --extra-vars "ssh_keys=\"${ANSIBLE_SSH_PUB_KEY}\" galera_prefix=${DISTRO}_${DATE} image=linode/${DISTRO}"
  ansible-playbook -i hosts site.yml --extra-vars "root_password=${ROOT_PASS}  add_keys_prompt=yes"
  verify
}

# main
case $1 in
    ansible:build) "$@"; exit;;
    ansible:deploy) "$@"; exit;;
    test:build) "$@"; exit;;
    test:deploy) "$@"; exit;;
esac
