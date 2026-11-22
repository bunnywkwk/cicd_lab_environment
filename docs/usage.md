# Usage

Every command runs from the **repository root**. Terraform commands use `-chdir=terraform`, so there is no `cd`.

| I want to | Batch |
| --- | --- |
| Prepare a new laptop or AWS account | [0. Set up once](#0-set-up-once) |
| Get the environment from nothing | [1. Build](#1-build) → [2. Configure](#2-configure) → [3. Check](#3-check) |
| Pause it for the night | [4. Stop](#4-stop) |
| Continue after a pause | [5. Start](#5-start) |
| Remove everything, pay nothing | [6. Destroy](#6-destroy) |

## 0. Set up once

Tools on the laptop: ansible-core 2.16+, Terraform 1.6+, AWS CLI v2.

```bash
sudo dnf install ansible-core awscli2
terraform version
```

AWS access: in the console, IAM → Users → create a user (no console access) with `AdministratorAccess`, then Security credentials → Create access key → Command Line Interface.

```bash
aws configure                    # the two keys, region ap-southeast-1, output json
aws sts get-caller-identity      # shows .../user/<your user>
```

- The keys live in `~/.aws/credentials` only: never in this repository.
- SSH key: Terraform uploads `~/.ssh/id_rsa.pub`; Ansible logs in with `~/.ssh/id_rsa`. Create one with `ssh-keygen` if missing.
- Set a budget alert in the AWS Billing console: the running environment costs about 0.53 USD per hour.

## 1. Build

```bash
terraform -chdir=terraform init      # first time only: downloads the providers
terraform -chdir=terraform plan      # shows what will be created, changes nothing
terraform -chdir=terraform apply     # type yes
```

Result: `Apply complete! Resources: 25 added`, the `instances` output with each host's public and private IP, and a new `sysconfig/inventory-aws.yml`.

## 2. Configure

```bash
ansible-galaxy install -r requirements.yml -p roles/ --force
ansible -i sysconfig/inventory-aws.yml all -m ping
ansible-playbook -i sysconfig/inventory-aws.yml playbooks/main_playbook.yml | tee runs/aws-run.log
```

- `ping`: `pong` from all 4.
- Playbook: `failed=0` on all 4. Run it again: `changed=0` everywhere.

## 3. Check

Public IPs: `terraform -chdir=terraform output`.

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://<rhel9-ci public IP>:8080/login    # 200
ssh ec2-user@<rhel9-ci public IP> 'curl -s http://localhost:5000/v2/_catalog'     # {"repositories":[...]}
ssh ec2-user@<k3s-master-1 public IP> 'sudo /usr/local/bin/k3s kubectl get nodes'  # 3 nodes Ready
```

Argo CD: open `https://<k3s-master-1 public IP>:30443`, user `admin`. First password:

```bash
ssh ec2-user@<k3s-master-1 public IP> "sudo /usr/local/bin/k3s kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
```

Log in, change the password (User Info → Update password), and **only then** delete the first-password secret:

```bash
ssh ec2-user@<k3s-master-1 public IP> 'sudo /usr/local/bin/k3s kubectl -n argocd delete secret argocd-initial-admin-secret'
```

`kubectl` needs `sudo /usr/local/bin/k3s kubectl`: the k3s kubeconfig is readable by root only.

## 4. Stop

```bash
terraform -chdir=terraform apply -var running=false      # type yes
```

- All 4 instances stop; disks and data stay. Only the disks are billed (about 0.20 USD a day).
- The public IPs are released: the `instances` output shows ` / 10.20.0.x`.

## 5. Start

```bash
terraform -chdir=terraform apply -var running=true       # type yes
terraform -chdir=terraform output
ansible-playbook -i sysconfig/inventory-aws.yml playbooks/main_playbook.yml --limit ci
```

- New public IPs; Terraform already rewrote `sysconfig/inventory-aws.yml`.
- k3s and the registry come back by themselves: they use the private IPs, which did not change.
- `--limit ci` runs only on `rhel9-ci`: Jenkins stores its own URL with the public IP, this updates it.

**Careful:** `terraform apply` without `-var` means `running=true`, so it starts stopped instances. Always type the `-var` you mean.

## 6. Destroy

```bash
terraform -chdir=terraform destroy      # type yes
```

Everything Terraform made is deleted, including `sysconfig/inventory-aws.yml`. Back to batch 1 to rebuild.

## Optional: own Jenkins password

The default is `admin`. To set your own, store it encrypted, never in plain text:

```bash
ansible-vault encrypt_string --ask-vault-password --name jenkins_admin_password >> sysconfig/group_vars/ci/jenkins.yml
```

Type the password, press Ctrl-D twice. From then on, add `-J` (ask for the vault password) to every `ansible-playbook` run.

## Optional: local VMs instead of AWS

Four RHEL 9 VMs with user `frqadmin` (sudo) and your SSH key: put their IPs in `sysconfig/inventory.yml`, then batch 2 without `-i sysconfig/inventory-aws.yml` (the default inventory in `ansible.cfg`).

## When something fails

| Error | Cause | Fix |
| --- | --- | --- |
| `Unable to parse .../sysconfig/inventory-aws.yml` | Not in the repository root, or no build yet | `cd` to the root; run batch 1 |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | AWS reused a public IP an old instance had | `ssh-keygen -R <that IP>` |
| SSH or the UIs time out | My home IP changed | `terraform -chdir=terraform apply` (it looks up the new IP) |
| `open /etc/rancher/k3s/k3s.yaml: permission denied` | `kubectl` as a normal user | `sudo /usr/local/bin/k3s kubectl ...` |
