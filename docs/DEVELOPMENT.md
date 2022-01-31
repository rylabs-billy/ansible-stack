# Contributing
After setting up a development environment, you can test your changes locally using Molecule, or against Linodes on your account. Please ensure that your tests pass on all supported Debian and Ubuntu releases. 

1. [Setup](#setup)
2. [Testing with Molecule](#testing-with-molecule)
3. [Testing on Linode](#testing-on-linode)

## Setup
Create a virtual environment to isolate dependencies from other packages on your system.
```
python3 -m virtualenv env
source env/bin/activate
```

Install Ansible collections and required Python packages.
```
pip install -r requirements.txt
ansible-galaxy collection install linode.cloud community.crypto community.mysql
```

## Testing with Molecule
Molecule is a framework for developing and testing Ansible roles. After installing Vagrant and Virtualbox, you can use Molecule to provision and test against Vagrant boxes in your local environment. This is the recommended approach, because it helps to enforce consistency and well-written roles. 
```
cd .tests/
molecule test -s debian10
molecule test -s ubuntu20.04
```

## Testing on Linode
If you cannot use the Molecule approach due to limitations in your local environment, you can instead provision and test against Linodes on your account. Note that billing will occur for any Linode instances that remain on the account longer than one hour.

The approach requires putting real values into the `.valut-pass`, `group_vars/galera/vars` and `group_vars/galera/secret_vars`. 

> :warning: WARNING: Clear these values before pushing changes to your fork in order to avoid exposing sensitive information.

Put your [vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html#encrypting-content-with-ansible-vault) password in the `.vault-pass` file. Encrypt your Linode root password and valid [APIv4 token](https://www.linode.com/docs/guides/getting-started-with-the-linode-api/#create-an-api-token) with `ansible-vault`. Replace the value of `@R34llyStr0ngP455w0rd!` with your own strong password and `pYPE7TvjNzmhaEc1rW4i` with your own access token.
```
ansible-vault encrypt_string '@R34llyStr0ngP455w0rd!' --name 'root_pass' >> group_vars/galera/secret_vars
ansible-vault encrypt_string 'pYPE7TvjNzmhaEc1rW4i' --name 'token' >> group_vars/galera/secret_vars
```

Configure the Linode instance [parameters](https://github.com/linode/ansible_linode/blob/master/docs/instance.rst#id3), `galera_prefix`, `cluster_name`, and SSL/TLS variables in `group_vars/galera/vars`. As with the above, replace the example values with your own. This playbook was written to support `linode/debian10` and `linode/ubuntu20.04` images.
```
# linode vars
ssh_keys: ssh-rsa AAAA_valid_public_ssh_key_123456785== user@their-computer
galera_prefix: galera
cluster_name: POC
type: g6-standard-4
region: ap-south
image: linode/debian10
group: galera-servers
linode_tags: POC

# ssl/tls vars
country_name: US
state_or_province_name: Pennsylvania
locality_name: Philadelphia
organization_name: Linode
email_address: user@linode.com
ca_common_name: Galera CA
common_name: Galera Server
```

Lint to ensure playbooks meet best practices and style rules. Make changes as needed until there are no violations.
```
ansible-lint
```

Run `provision.yml` to stand up the Linode instances and dynamically write your Ansible inventory to the `hosts` file.
```
ansible-playbook provision.yml
```

Now run the `site.yml` playbook with the `hosts` inventory file. 
```
ansible-playbook -i hosts site.yml
```

