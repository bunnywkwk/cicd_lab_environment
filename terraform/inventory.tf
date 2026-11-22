# Batch 4 step 1 as code: the playbook's AWS inventory, rewritten at every apply with the current IPs.

resource "local_file" "inventory" {
  filename        = "${path.module}/../sysconfig/inventory-aws.yml"
  file_permission = "0644"
  content = templatefile("${path.module}/inventory.yml.tftpl", {
    ci  = { public_ip = data.aws_instance.ci.public_ip, private_ip = data.aws_instance.ci.private_ip }
    k3s = { for name, i in data.aws_instance.k3s : name => { public_ip = i.public_ip, private_ip = i.private_ip } }
  })
}

output "instances" {
  description = "Name = public IP / private IP"
  value = merge(
    { (aws_instance.ci.tags.Name) = "${data.aws_instance.ci.public_ip} / ${data.aws_instance.ci.private_ip}" },
    { for name, i in data.aws_instance.k3s : name => "${i.public_ip} / ${i.private_ip}" },
  )
}
