# CI/CD Lab Master

Ansible project that builds the **CI/CD lab** on RHEL 9 VMs: a CI host that builds and stores images, and a k3s cluster with Argo CD that will run them.

It does not contain the automation logic itself. It orders three roles, each pulled from its own repository, and holds the settings for them:

| Role | What it does | Source |
| :--- | :--- | :--- |
| `registry` | Container registry (`registry:2` under Podman Quadlet) on port 5000, plain HTTP, no login | `bunnywkwk/ansible-role-registry` |
| `jenkins` | Jenkins (RPM, JCasC, plugins) with rootless Podman to build and push images | `bunnywkwk/ansible-role-jenkins` |
| `k3s` | k3s cluster (1 server + agents) with Argo CD, pulling from the lab registry | `bunnywkwk/ansible-role-k3s` |

---

## Repository layout

```text
.
├── ansible.cfg                      # inventory and roles path
├── requirements.yml                 # roles and collections to install
├── playbooks/
│   └── main_playbook.yml            # the three phases
├── sysconfig/
│   ├── inventory.yml                # hosts and groups
│   ├── inventory-aws.yml.example    # AWS hosts template; the real inventory-aws.yml (live IPs) is not in git
│   └── group_vars/
│       ├── all.yml                  # SSH user and key
│       ├── ci/registry.yml          # registry port (Jenkins and k3s read it)
│       ├── ci/jenkins.yml           # Jenkins settings
│       └── k3s_cluster/k3s.yml      # k3s settings
├── runs/                            # saved run output (test evidence)
└── roles/                           # installed by ansible-galaxy, not stored in git
```

| VM | Group | IP |
| :--- | :--- | :--- |
| `rhel9-ci` | `ci` | 192.168.122.135 |
| `k3s-master-1` | `k3s_server` | 192.168.122.165 |
| `k3s-worker-1`, `k3s-worker-2` | `k3s_agent` | 192.168.122.26, .139 |

The registry address is written once: `jenkins_url` comes from the CI host's `ansible_host`, and the registry addresses Jenkins and k3s use (`jenkins_insecure_registries`, `k3s_insecure_registries`) from `ansible_host` plus `registry_port` in `ci/registry.yml`.

---

## What the playbook does

`playbooks/main_playbook.yml` has three plays, run in this order:

1. **Phase 1, CI host** (`ci`): checks the Ansible version, then runs `registry` and `jenkins` (registry first: Jenkins pushes to it).
2. **Phase 2, k3s server** (`k3s_server`): runs `k3s` as server; k3s then installs Argo CD.
3. **Phase 3, k3s agents** (`k3s_agent`): runs `k3s` as agent; each agent reads the server's token and joins.

The server comes before the agents because they join a running server. No play gathers facts: the roles do not use them, and a play with all its tasks skipped by `--tags` then does not connect to its hosts.

---

## Requirements

- ansible-core 2.16 or newer on the control machine.
- RHEL 9 VMs, registered (packages from Red Hat), with internet access; about 2 vCPU / 2 GB RAM each.
- SSH key access as `frqadmin`, with `sudo` rights (`ssh-copy-id frqadmin@<vm-ip>` once per VM).

---

## Usage

### 1. Install the roles and collections

```bash
ansible-galaxy install -r requirements.yml -p roles/ --force
```

This downloads the three roles into `roles/` and the `ansible.posix` collection. It overwrites what is in `roles/`, so push any role change to GitHub first.

### 2. Change the Jenkins admin password (optional)

The role's default is `admin` (lab). To use your own, store it as a vault string, never in plain text:

```bash
ansible-vault encrypt_string --ask-vault-password --name jenkins_admin_password >> sysconfig/group_vars/ci/jenkins.yml
```

Type the password, then press Ctrl-D twice. Runs then need `--ask-vault-password` (`-J`).

### 3. Run the playbook

```bash
ansible-playbook playbooks/main_playbook.yml -J | tee runs/<name>.log
```

### Run one part

```bash
ansible-playbook playbooks/main_playbook.yml -J --tags jenkins      # one role: registry, jenkins or k3s
ansible-playbook playbooks/main_playbook.yml --limit k3s_cluster    # only the cluster (no vault needed)
```

### Re-running

A second run reports `changed=0` on every host. k3s restarts only when its config changes; a new `k3s_version` upgrades it.

---

## Check the result

```bash
curl -s http://192.168.122.135:5000/v2/_catalog                            # registry answers
curl -s -o /dev/null -w '%{http_code}\n' http://192.168.122.135:8080/login  # Jenkins: 200
ssh frqadmin@192.168.122.165 'sudo /usr/local/bin/k3s kubectl get nodes'    # 3 nodes Ready
```

Argo CD UI: `https://192.168.122.165:30443`, user `admin`. Password:

```bash
ssh frqadmin@192.168.122.165 "sudo /usr/local/bin/k3s kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
```

---

## Documentation

Each role documents itself in its own repository: `README.md`, then `docs/code-walkthrough.md`, `docs/design-decisions.md` and `docs/test-results.md` (all checks, with results and the logs in `runs/`).
