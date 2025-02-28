resource "aws_instance" "dns" {
  ami           = var.al2023_ami
  instance_type = "t3.small"
  subnet_id     = var.public_subnet_id
  private_ip    = var.dns_ip
  security_groups = [ var.security_group ]
  key_name = var.key_name

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  user_data = base64encode(file("${path.module}/dns_userdata.tpl"))

  tags = {
    Name = "okd-dns"
  }
}

resource "aws_instance" "lb" {
  ami           = var.al2023_ami
  instance_type = "t3.small"
  subnet_id     = var.public_subnet_id
  private_ip    = var.lb_ip
  security_groups = [ var.security_group ]
  key_name = var.key_name

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  user_data = base64encode(templatefile("${path.module}/lb_userdata.tpl", {}))

  tags = {
    Name = "okd-lb"
  }
}

resource "aws_instance" "manager" {
  ami           = var.al2023_ami
  instance_type = "t3.small"
  subnet_id     = var.public_subnet_id
  private_ip    = var.manager_ip
  security_groups = [ var.security_group ]
  key_name = var.key_name

  user_data = base64encode(templatefile("${path.module}/mgr_userdata.tpl", {
    pullSecret = var.pullSecret
  }))

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "okd-manager"
  }
}

resource "aws_instance" "bootstrap" {
  ami           = var.fcos_ami
  instance_type = "t3.xlarge"
  subnet_id     = var.private_subnet_id
  private_ip    = var.bootstrap_ip
  security_groups = [ var.security_group ]
  key_name = var.key_name

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }

  tags = {
    Name = "bootstrap"
  }
}

resource "aws_instance" "control-plane" {
  count         = length(var.control_plane_ips)
  ami           = var.fcos_ami
  instance_type = "t3.xlarge"
  subnet_id     = var.private_subnet_id
  private_ip    = var.control_plane_ips[count.index]
  security_groups = [ var.security_group ]
  key_name = var.key_name

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }

  tags = {
    Name = "control-plane-${count.index + 1}"
  }
}

# resource "aws_instance" "worker" {
#   count         = length(var.worker_ips)
#   ami           = var.fcos_ami
#   instance_type = "t3.large"
#   subnet_id     = var.private_subnet_id
#   private_ip    = var.worker_ips[count.index]
#   security_groups = [ var.security_group ]
#   key_name = var.key_name

#   root_block_device {
#     volume_size = 100
#     volume_type = "gp3"
#   }

#   tags = {
#     Name = "worker-${count.index + 1}"
#   }
# }