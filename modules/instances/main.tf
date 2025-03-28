resource "aws_instance" "dns" {
  ami             = var.AL2023
  instance_type   = var.server_instance
  subnet_id       = var.public_subnet_id
  private_ip      = var.dns_ip
  security_groups = [var.dns_sg]
  key_name        = var.key_name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = base64encode(templatefile("${path.module}/template/dns.tpl", {
    domain_name  = var.domain_name,
    cluster_name = var.cluster_name,
    dns_ip       = var.dns_ip,
    lb_ip        = var.lb_ip,
    bootstrap_ip = var.bootstrap_ip,
    control0_ip  = var.control_plane_ips[0],
    control1_ip  = var.control_plane_ips[1],
    control2_ip  = var.control_plane_ips[2],
    worker0_ip   = var.worker_ips[0],
    worker1_ip   = var.worker_ips[1],
    worker2_ip   = var.worker_ips[2],
    nat_ip       = var.nat_ip,
    manager_ip   = var.manager_ip,
    nfs_ip       = var.nfs_ip,
    db0_ip       = var.db_ips[0],
    db1_ip       = var.db_ips[1],
    gitea_ip     = var.gitea_ip,
    monitor_ip   = var.monitor_ip
  }))

  tags = {
    Name = "${var.name}-dns"
  }
}

resource "aws_vpc_dhcp_options" "okd_dns_resolver" {
  domain_name_servers = [var.dns_ip]
  domain_name         = "${var.cluster_name}.${var.domain_name}"

  tags = {
    Name = "ocp-dns"
  }
}

resource "aws_vpc_dhcp_options_association" "okd_dns_resolver" {
  vpc_id          = var.vpc_id
  dhcp_options_id = aws_vpc_dhcp_options.okd_dns_resolver.id

  depends_on = [null_resource.finish_dns]
}

resource "aws_instance" "lb" {
  ami             = var.AL2023
  instance_type   = var.server_instance
  subnet_id       = var.public_subnet_id
  private_ip      = var.lb_ip
  security_groups = [var.lb_sg]
  key_name        = var.key_name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = base64encode(templatefile("${path.module}/template/lb.tpl", {
    domain_name  = var.domain_name,
    cluster_name = var.cluster_name
  }))

  tags = {
    Name = "${var.name}-lb"
  }

}

resource "aws_instance" "monitor" {
  ami             = var.AL2023
  instance_type   = var.server_instance
  subnet_id       = var.public_subnet_id
  private_ip      = var.monitor_ip
  security_groups = [var.monitor_sg]
  key_name        = var.key_name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = base64encode(templatefile("${path.module}/template/monitor.tpl", {
    monitor_ip = var.monitor_ip,
    nat_ip     = var.nat_ip,
    manager_ip = var.manager_ip,
    lb_ip      = var.lb_ip,
    dns_ip     = var.dns_ip,
    nfs_ip     = var.nfs_ip,
    db0_ip     = var.db_ips[0],
    db1_ip     = var.db_ips[1],
    gitea_ip   = var.gitea_ip
  }))

  tags = {
    Name = "${var.name}-monitor"
  }

}

resource "aws_instance" "manager" {
  # ami           = "ami-004ab59fd9ba73fac"
  ami             = var.AL2023
  instance_type   = var.server_instance
  subnet_id       = var.public_subnet_id
  private_ip      = var.manager_ip
  security_groups = [var.manager_sg]
  key_name        = var.key_name

  user_data = base64encode(templatefile("${path.module}/template/mgr.tpl", {
    domain_name   = var.domain_name,
    cluster_name  = var.cluster_name,
    pullSecret    = var.pullSecret,
    control_count = var.control_plane_count,
    worker_count  = var.worker_count
  }))

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.name}-manager"
  }
}

# resource "aws_instance" "waf" {
#   ami             = var.AL2023
#   instance_type   = var.server_instance
#   subnet_id       = var.public_subnet_id
#   private_ip      = var.waf_ip
#   security_groups = [var.waf_sg]
#   key_name        = var.key_name

#   user_data = base64encode(file("${path.module}/template/waf.sh"))

#   root_block_device {
#     volume_size = 30
#     volume_type = "gp3"
#   }

#   tags = {
#     Name = "${var.name}-waf"
#   }
# }


resource "null_resource" "finish_dns" {
  depends_on = [aws_instance.dns]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(var.ec2_ssh_key)
    host        = aws_instance.dns.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /tmp/user_data_complete ]; do sleep 10; done",
      "echo 'User data script completed'"
    ]
  }
}

resource "null_resource" "finish_mgr" {
  depends_on = [aws_instance.manager]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(var.ec2_ssh_key)
    host        = aws_instance.manager.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /tmp/user_data_complete ]; do sleep 10; done",
      "echo 'User data script completed'"
    ]
  }
}
