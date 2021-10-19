#!/bin/bash
set -e
trap "cleanup $? $LINENO" EXIT

function cleanup {
  if [ "$?" != "0" ]; then
    echo "PLAYBOOK FAILED. See /var/log/stackscript.log for details."
    rm ${HOME}/.ssh/id_ansible_ed25519*
    destroy
    exit 1
  fi
}

# global constants
readonly ANSIBLE_SSH_PUB_KEY=$(ssh-keygen -o -a 100 -t ed25519 -C "ansible" -f "${HOME}/.ssh/id_ansible_ed25519" -q -N "" <<<y >/dev/null && cat ${HOME}/.ssh/id_ansible_ed25519.pub)
readonly ANSIBLE_SSH_PRIV_KEY=$(cat ${HOME}/.ssh/id_ansible_ed25519)
readonly ANSIBLE_SSH_KEY_PATH="${HOME}/.ssh/id_ansible_ed25519"
readonly ROOT_PASS=$(cat /etc/shadow | grep root)
readonly TEMP_ROOT_PASS=$(openssl rand -base64 32)
readonly GIT_REPO="https://rylabs-billy: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@github.com/rylabs-billy/ansible-stack.git"
readonly LINODE_PARAMS=($(curl -sH "Authorization: Bearer ${TOKEN_PASSWORD}" "https://api.linode.com/v4/linode/instances/${LINODE_ID}" | jq -r .type,.region,.image,.label))
readonly TAGS=$(curl -sH "Authorization: Bearer ${TOKEN_PASSWORD}" "https://api.linode.com/v4/linode/instances/${LINODE_ID}" | jq -r .tags)
readonly PUBLIC_IP=$(curl -sH "Authorization: Bearer ${TOKEN_PASSWORD}" "https://api.linode.com/v4/linode/instances/${LINODE_ID}" | jq -r .ipv4[0])
readonly VARS_PATH="./group_vars/galera/vars"
#readonly ANSIBLE_SSH_KEY=$(echo | ssh-keygen -o -a 100 -t ed25519 -C "ansible" -f "$HOME/.ssh/id_ansible_ed25519" > /dev/null && cat $HOME/.ssh/id_ansible_ed25519.pub)
#readonly VAULT_PASS=$(openssl rand -base64 32)
#readonly DATETIME=$(date '+%Y-%m-%d_%H%M%S')
#readonly SECRET_VARS_PATH="./group_vars/galera/secret_vars"
#readonly UBUNTU_IMAGE="linode/ubuntu20.04"
#readonly DEBIAN_IMAGE="linode/debian10"

# utility functions
function env {
  source env/bin/activate
}

function destroy {
    ansible-playbook -i hosts destroy.yml --extra_vars "token=${TOKEN_PASSWORD}"
}

function private_ip {
  local PRIVATE_IP=$(curl -sH "Authorization: Bearer ${TOKEN_PASSWORD}" "https://api.linode.com/v4/linode/instances/${LINODE_ID}" | jq -r .ipv4[1])
  if [[ "${PRIVATE_IP}" != *"192.168"* ]];
  then
    curl -sH "Content-Type: application/json" \
      -H "Authorization: Bearer ${TOKEN_PASSWORD}" \
      -X POST -d '{
        "type": "ipv4",
        "public": false,
        "linode_id": '$LINODE_ID'
      }'  https://api.linode.com/v4/networking/ips

    # configure private ip on control node
    local PRIVATE_IP=$(curl -sH "Authorization: Bearer ${TOKEN_PASSWORD}" "https://api.linode.com/v4/linode/instances/${LINODE_ID}" | jq -r .ipv4[1])
    ip addr add ${PRIVATE_IP}/17 dev eth0 label eth0:1
    echo "    up   ip addr add 192.168.146.211/17 dev eth0 label eth0:1" >> /etc/network/interfaces
    echo "    down ip addr del 192.168.146.211/17 dev eth0 label eth0:1" >> /etc/network/interfaces
    cat /etc/network/interfaces #for testing
  fi
}

function ansible:vars {
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
}

function ansible:deploy {
  # run provision playbook
  #echo -e "\nprivate_key_file = ${ANSIBLE_SSH_KEY_PATH}" >> ansible.cfg
  ansible-playbook provision.yml --extra-vars "localhost_public_ip=${PUBLIC_IP} localhost_private_ip=${PRIVATE_IP} root_pass=${TEMP_ROOT_PASS} token=${TOKEN_PASSWORD}" --flush-cache
  # run galera playbook
  ansible-playbook -i hosts site.yml -vvv --extra-vars "root_password=${ROOT_PASS} add_keys_prompt=${ADD_SSH_KEYS}"
}

case $1 in
    private_ip) "$@"; exit;;
    ansible:vars) "$@"; exit;;
    ansible:deploy) "$@"; exit;;
esac

# main
private_ip
ansible