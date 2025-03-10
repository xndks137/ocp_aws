resource "aws_instance" "dns" {
  ami           = var.AL2023
  instance_type = var.server_instance
  subnet_id     = var.public_subnet_id
  private_ip    = var.dns_ip
  security_groups = [ var.dns_sg ]
  key_name = var.key_name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = base64encode(templatefile("${path.module}/template/dns.tpl", {
    domain_name= var.domain_name,
    cluster_name=var.cluster_name,
    dns_ip=var.dns_ip,
    lb_ip=var.lb_ip,
    bootstrap_ip=var.bootstrap_ip,
    control0_ip=var.control_plane_ips[0],
    control1_ip =var.control_plane_ips[1],
    control2_ip=var.control_plane_ips[2],
    worker0_ip = var.worker_ips[0],
    worker1_ip = var.worker_ips[1],
    worker2_ip = var.worker_ips[2]
  }))

  tags = {
    Name = "${var.cluster_name}-dns"
  }
}

resource "aws_vpc_dhcp_options" "okd_dns_resolver" {
  domain_name_servers = [var.dns_ip]
  domain_name = "${var.cluster_name}.${var.domain_name}"

  tags = {
    Name = "ocp-dns"
  }
}

resource "aws_vpc_dhcp_options_association" "okd_dns_resolver" {
  vpc_id          = var.vpc_id
  dhcp_options_id = aws_vpc_dhcp_options.okd_dns_resolver.id

  depends_on = [ null_resource.finish_dns ]
}

resource "aws_instance" "lb" {
depends_on = [ aws_vpc_dhcp_options_association.okd_dns_resolver ]
  ami           = var.AL2023
  instance_type = var.server_instance
  subnet_id     = var.public_subnet_id
  private_ip    = var.lb_ip
  security_groups = [ var.lb_sg ]
  key_name = var.key_name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = base64encode(templatefile("${path.module}/template/lb.tpl", {
    domain_name = var.domain_name,
    cluster_name = var.cluster_name
  }))

  tags = {
    Name = "${var.cluster_name}-lb"
  }

}

resource "aws_instance" "manager" {
depends_on = [ aws_vpc_dhcp_options_association.okd_dns_resolver ]
  ami           = var.AL2023
  instance_type = var.server_instance
  subnet_id     = var.public_subnet_id
  private_ip    = var.manager_ip
  security_groups = [ var.manager_sg ]
  key_name = var.key_name

  user_data = base64encode(templatefile("${path.module}/template/mgr.tpl", {
    domain_name = var.domain_name,
    cluster_name = var.cluster_name,
    pullSecret = var.pullSecret,
    control_count = length(var.control_plane_ips),
    worker_count = length(var.worker_ips)
  }))

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.cluster_name}-manager"
  }
}

resource "aws_instance" "bootstrap" {
  depends_on = [ null_resource.finish_mgr, var.sgw_instance_id ]
  ami           = var.RHCOS
  instance_type = var.ocp_instance
  subnet_id     = var.private_subnet_id
  private_ip    = var.bootstrap_ip
  security_groups = [ var.bootstrap_sg ]
  key_name = var.key_name

  user_data = "{\"ignition\":{\"config\":{\"replace\":{\"source\":\"http://${var.manager_ip}:8080/bootstrap.ign\"}},\"version\":\"3.1.0\"}}"

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.cluster_name}-bootstrap"
  }
}

resource "aws_instance" "control-plane" {
  depends_on = [ null_resource.finish_mgr, var.sgw_instance_id ]
  count         = length(var.control_plane_ips)
  ami           = var.RHCOS
  instance_type = var.ocp_instance
  subnet_id     = var.private_subnet_id
  private_ip    = var.control_plane_ips[count.index]
  security_groups = [ var.master_sg ]
  key_name = var.key_name

  user_data = "{\"ignition\":{\"config\":{\"replace\":{\"source\":\"http://${var.manager_ip}:8080/master.ign\"}},\"version\":\"3.1.0\"}}"

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.cluster_name}-control-plane-${count.index + 1}"
  }

}

resource "aws_instance" "worker" {
  depends_on = [ null_resource.finish_mgr, var.sgw_instance_id ]
  count         = length(var.worker_ips)
  ami           = var.RHCOS
  instance_type = var.ocp_instance
  subnet_id     = var.private_subnet_id
  private_ip    = var.worker_ips[count.index]
  security_groups = [ var.worker_sg ]
  key_name = var.key_name

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }

  user_data = "{\"ignition\":{\"config\":{\"replace\":{\"source\":\"http://${var.manager_ip}:8080/worker.ign\"}},\"version\":\"3.1.0\"}}"

  tags = {
    Name = "${var.cluster_name}-worker-${count.index + 1}"
  }
}

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
