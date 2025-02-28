resource "aws_instance" "dns" {
  ami           = var.al2023_ami
  instance_type = "t3.small"
  subnet_id     = var.public_subnet_id
  private_ip    = var.dns_ip
  security_groups = [ var.pub_sg ]
  key_name = var.key_name

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  user_data = base64encode(file("${path.module}/template/dns.tpl"))

  tags = {
    Name = "okd-dns"
  }
}

resource "aws_instance" "lb" {
  depends_on = [ aws_instance.dns ]
  ami           = var.al2023_ami
  instance_type = "t3.small"
  subnet_id     = var.public_subnet_id
  private_ip    = var.lb_ip
  security_groups = [ var.pub_sg ]
  key_name = var.key_name

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  user_data = base64encode(file("${path.module}/template/lb.tpl"))

  tags = {
    Name = "okd-lb"
  }
}

resource "aws_instance" "manager" {
  depends_on = [ aws_instance.dns ]
  ami           = var.al2023_ami
  instance_type = "t3.small"
  subnet_id     = var.public_subnet_id
  private_ip    = var.manager_ip
  security_groups = [ var.pub_sg ]
  key_name = var.key_name

  user_data = base64encode(templatefile("${path.module}/template/mgr.tpl", {
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
  security_groups = [ var.bootstrap_sg ]
  key_name = var.key_name
  iam_instance_profile = var.bootstrap_iam

  user_data = "{\"ignition\":{\"config\":{\"replace\":{\"source\":\"${var.manager_ip}/bootstrap.ign\"}},\"version\":\"3.1.0\"}}"

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }

  tags = {
    Name = "bootstrap"
  }

  depends_on = [ aws_instance.dns , null_resource.finish_mgr ]
}

resource "aws_instance" "control-plane" {
  count         = length(var.control_plane_ips)
  ami           = var.fcos_ami
  instance_type = "t3.xlarge"
  subnet_id     = var.private_subnet_id
  private_ip    = var.control_plane_ips[count.index]
  security_groups = [ var.master_sg ]
  key_name = var.key_name
  iam_instance_profile = var.master_iam

  user_data = "{\"ignition\":{\"config\":{\"replace\":{\"source\":\"${var.manager_ip}/master.ign\"}},\"version\":\"3.1.0\"}}"

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }

  tags = {
    Name = "control-plane-${count.index + 1}"
  }
  
  depends_on = [ aws_instance.dns , null_resource.finish_mgr ]

}

# resource "aws_instance" "worker" {
#   count         = length(var.worker_ips)
#   ami           = var.fcos_ami
#   instance_type = "t3.large"
#   subnet_id     = var.private_subnet_id
#   private_ip    = var.worker_ips[count.index]
#   security_groups = [ var.worker_sg ]
#   key_name = var.key_name
#   iam_instance_profile = var.worker_iam

#   root_block_device {
#     volume_size = 100
#     volume_type = "gp3"
#   }

#   user_data = "{\"ignition\":{\"config\":{\"replace\":{\"source\":\"${var.manager_ip}/worker.ign\"}},\"version\":\"3.1.0\"}}"

#   tags = {
#     Name = "worker-${count.index + 1}"
#   }
# }

resource "null_resource" "finish_mgr" {
  depends_on = [aws_instance.manager]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("${path.module}/privateKEY")
    host        = aws_instance.manager.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /tmp/user_data_complete ]; do sleep 10; done",
      "echo 'User data script completed'"
    ]
  }
}
