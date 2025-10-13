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

### Inventory

You should add your home server's IP address or host name to the `homeserver` host in the `inventory/hosts.yml` file.

To encrypt your own `ansible_host`, you can use:

```shell
ansible-vault encrypt_string 'remote-server' --name 'ansible_host'
```

Substituting `remote-server` with your remote host's actual IP or host name. You can then paste that into the `hosts.yml` file.

You can test running commands on the remote host with:

```shell
ansible all -m command -a "uptime" -i inventory
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

## Playbook: setup-caddy.yml

Caddy is used to reverse proxy the services on the media server so that they can be served over HTTPS on the web.

Caddy can be set up with the `setup-caddy.yml` playbook. The `caddy` role assumes you are using Cloudflare for your domains, so requires at minimum a Cloudflare API token to authenticate with.

**You should run this playbook *after* setting up the services that will be reverse proxied**. Otherwise, Caddy will complain about not being able to get certificates for your domains.

```shell
ansible-playbook -i inventory setup-caddy.yml
```

The services that caddy reverse proxies should be defined in `host_vars/homeserver.yml`. The `reverse_proxy_hosts` should be a list of objects containing three attributes (see below). For example, this will set Caddy to reverse proxy two services:

```yaml
caddy:
  reverse_proxy_hosts:
    - domain_name: the-public.domain.com
      container_name: the_container_name
      port: the_exposed_port
    - domain_name: example.com
      container_name: the_other_container_name
      port: the_other_exposed_port
```

Any container or pod that uses the `web-services.network` can be reverse proxied by Caddy.

If your host does not have a static IP (e.g., if your ISP does not allow it), there is an included script that is deployed that will update the IPv4 address of your domains to the host's IP address whenever it changes. To enable this feature, set:

```yaml
caddy:
  host_ip_is_static: false
```

And the script will be deployed automatically. All of the DNS records within the set `caddy_cloudflare_zone_id` (i.e., the given Zone in Cloudflare) will have the IP address of their DNS A records set to the remote host's IP address.

Note that you will need to enable port forwarding for ports 80/tcp, 443/tcp, and 443/udp on your router as well if you want your services publicly accessible.

### Secret Variables

These variable needs to be set before running this playbook:

| Name                         | Description                                                  | Requirement                |
| ---------------------------- | ------------------------------------------------------------ | -------------------------- |
| v_caddy_cloudflare_api_token | The cloudflare API token used for authentication             | Always required            |
| v_caddy_cloudflare_zone_id   | The zone ID of the DNS records pointing to the remote server | When host IP is not static |
