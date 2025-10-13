# Media Server Setup

Set up home media server automatically with [Ansible](https://docs.ansible.com/ansible/latest/getting_started/introduction.html).

## Ansible Setup

To install Ansible on your control node (i.e., the host where you are running the playbooks from), use [uv](https://docs.astral.sh/uv/getting-started/installation/).

After installing `uv`, pull this repository and run:

```shell
uv venv
uv sync
```

You will need to make sure the requirements are installed before running any playbooks:

```shell
ansible-galaxy collection install -r requirements.yml
```

### Editor Setup

If you're using VSCode, install recommended extensions by searching for `@recommended` in the extensions search box and install all the extensions listed there.
