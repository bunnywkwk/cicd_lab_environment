# Batch 3 as code: rhel9-ci and the three k3s nodes.

locals {
  k3s_nodes = ["k3s-master-1", "k3s-worker-1", "k3s-worker-2"]
}

resource "aws_instance" "ci" {
  ami                    = var.ami_id
  instance_type          = var.ci_instance_type
  key_name               = aws_key_pair.cicd.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ci.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "rhel9-ci"
  }
}

resource "aws_instance" "k3s" {
  for_each = toset(local.k3s_nodes)

  ami                    = var.ami_id
  instance_type          = var.k3s_instance_type
  key_name               = aws_key_pair.cicd.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.k3s.id]

  root_block_device {
    volume_size = 15
    volume_type = "gp3"
  }

  tags = {
    Name = each.key
  }
}

# Batch 7: the on/off switch. terraform apply -var running=false stops all four, running=true starts them.
resource "aws_ec2_instance_state" "ci" {
  instance_id = aws_instance.ci.id
  state       = var.running ? "running" : "stopped"
}

resource "aws_ec2_instance_state" "k3s" {
  for_each = aws_instance.k3s

  instance_id = each.value.id
  state       = var.running ? "running" : "stopped"
}

# Read the instances again after the switch: a start gives new public IPs, which aws_instance only learns on the next refresh.
data "aws_instance" "ci" {
  instance_id = aws_instance.ci.id
  depends_on  = [aws_ec2_instance_state.ci]
}

data "aws_instance" "k3s" {
  for_each = aws_instance.k3s

  instance_id = each.value.id
  depends_on  = [aws_ec2_instance_state.k3s]
}
