# Media Server Setup

Set up home media server automatically with [Ansible](https://docs.ansible.com/ansible/latest/getting_started/introduction.html).

## Ansible Setup

These steps will enable you to run the playbooks from your control node on the media server remote.

### Control Node Setup

To install Ansible on your control node (i.e., the host where you are running the playbooks from), use [uv](https://docs.astral.sh/uv/getting-started/installation/).

After installing `uv`, pull this repository and run:

```shell
uv venv
source .venv/bin/activate
uv sync
```

If you're using VSCode, you'll need to set the Python interpeter Path.

- Press **CTRL + Shift + P**
- Enter **Python: Select Interpreter**
- Select **.venv/bin/python**
- Restart your terminal if you have one open. You should see `(ansible-media-server)` at the start of your prompt if the virtual environment is activated correctly.

Prior to running any playbooks, double check that the required Ansible collections are installed:

```shell
ansible-galaxy collection install -r requirements.yml
```

### Remote Host Setup

Prior to running the playbooks here, ensure there is a user account called `ansible` on the target (i.e., the remote home server), and that it has the ability to run sudo without a password. Run these commands on the remote server (sudo access needed):

```shell
# Create user with a home directory
sudo useradd --create-home ansible
sudo groupadd ansible
sudo usermod -aG ansible ansible

# Set the user's password
sudo passwd ansible

# Give the user access to run sudo
sudo echo "ansible ALL = (root) NOPASSWD:ALL" > /etc/sudoers.d/ansible
```

Additionally, ensure you add the public key of your control node to the ansible user's `authorized_keys` file.

First, make a public key if you don't have one on your control node.

```shell
ssh-keygen -t ed25519
```

Then run the following command from your control node to add your public key to the ansible user's authorized keys. Substitute `home-server` with your home server's actual host name.

```shell
ssh ansible@home-server sh -c "cat - >> ~/.ssh/authorized_keys" < ~/.ssh/id_ed25119.pub
```

## Secrets

It's recommended to store API tokens and other secret variables in an Ansible vault. If you create an Ansible vault at `group_vars/all/vault.yml`, Ansible will pick them up automatically. You can store the password to the vault anywhere outside of this repository, but I store it in a file called `~/.ansible_vault_password`.

You can edit the variables in the encrypted file with:

```shell
export ANSIBLE_VAULT_PASSWORD_FILE=~/.ansible_vault_password
export EDITOR=vim
ansible-vault edit group_vars/all/vault.yml
```

### Required Secrets

All encrypted variables are given a `v_` prefix. Deploying some services require certain secrets to be set, see the description for each service.

## Editor Setup

If you're using VSCode, install recommended extensions by searching for `@recommended` in the extensions search box and install all the extensions listed there.
