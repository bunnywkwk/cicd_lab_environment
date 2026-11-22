# Batch 2 as code: key pair and the two security groups.

resource "aws_key_pair" "cicd" {
  key_name   = "cicd-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# "My IP" from the console: ask AWS which public IP this laptop has, at every plan.
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  my_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}

resource "aws_security_group" "ci" {
  name        = "cicd-ci-sg"
  description = "SSH and Jenkins Access"
  vpc_id      = aws_vpc.cicd.id

  tags = {
    Name = "cicd-ci-sg"
  }
}

resource "aws_security_group" "k3s" {
  name        = "cicd-k3s-sg"
  description = "SSH and ArgoCD"
  vpc_id      = aws_vpc.cicd.id

  tags = {
    Name = "cicd-k3s-sg"
  }
}

# --- cicd-ci-sg inbound ---
resource "aws_vpc_security_group_ingress_rule" "ci_ssh" {
  security_group_id = aws_security_group.ci.id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = local.my_cidr
}

resource "aws_vpc_security_group_ingress_rule" "ci_jenkins" {
  security_group_id = aws_security_group.ci.id
  ip_protocol       = "tcp"
  from_port         = 8080
  to_port           = 8080
  cidr_ipv4         = local.my_cidr
}

resource "aws_vpc_security_group_ingress_rule" "ci_registry_from_k3s" {
  security_group_id            = aws_security_group.ci.id
  ip_protocol                  = "tcp"
  from_port                    = 5000
  to_port                      = 5000
  referenced_security_group_id = aws_security_group.k3s.id
}

# --- cicd-k3s-sg inbound ---
resource "aws_vpc_security_group_ingress_rule" "k3s_ssh" {
  security_group_id = aws_security_group.k3s.id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = local.my_cidr
}

resource "aws_vpc_security_group_ingress_rule" "k3s_argocd" {
  security_group_id = aws_security_group.k3s.id
  ip_protocol       = "tcp"
  from_port         = 30443
  to_port           = 30443
  cidr_ipv4         = local.my_cidr
}

resource "aws_vpc_security_group_ingress_rule" "k3s_from_k3s" {
  security_group_id            = aws_security_group.k3s.id
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.k3s.id
}

# --- outbound: all traffic, like the console default (Terraform removes that default, so it is written here) ---
resource "aws_vpc_security_group_egress_rule" "ci_all" {
  security_group_id = aws_security_group.ci.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "k3s_all" {
  security_group_id = aws_security_group.k3s.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
