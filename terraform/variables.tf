variable "region" {
  description = "AWS region: Singapore, closest full region to the Philippines"
  type        = string
  default     = "ap-southeast-1"
}

variable "ami_id" {
  description = "RHEL 9.8 pay-as-you-go image (Red Hat, 2026-10-21); pinned so every build gets the same OS"
  type        = string
  default     = "ami-057abfd202f3c10d7"
}

variable "ci_instance_type" {
  description = "rhel9-ci: registry + Jenkins"
  type        = string
  default     = "m7i-flex.large"
}

variable "k3s_instance_type" {
  description = "k3s master and workers"
  type        = string
  default     = "c7i-flex.large"
}

variable "ssh_public_key_path" {
  description = "Public half of the key the playbook uses (ansible_ssh_private_key_file)"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "running" {
  description = "true = instances running, false = stopped (only the disks are billed)"
  type        = bool
  default     = true
}
