
resource "aws_instance" "bootstrap" {
  depends_on      = [var.finish_mgr, var.sgw_instance]
  ami             = var.RHCOS
  instance_type   = var.ocp_instance
  subnet_id       = var.private_subnet_id
  private_ip      = var.bootstrap_ip
  security_groups = [var.bootstrap_sg]
  key_name        = var.key_name

  user_data = "{\"ignition\":{\"config\":{\"replace\":{\"source\":\"http://${var.manager_ip}:8080/bootstrap.ign\"}},\"version\":\"3.1.0\"}}"

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.name}-bootstrap"
  }
}

resource "aws_instance" "control-plane" {
  depends_on      = [var.finish_mgr, var.sgw_instance]
  count           = var.control_plane_count
  ami             = var.RHCOS
  instance_type   = var.ocp_instance
  subnet_id       = var.private_subnet_id
  private_ip      = var.control_plane_ips[count.index]
  security_groups = [var.master_sg]
  key_name        = var.key_name

  user_data = "{\"ignition\":{\"config\":{\"replace\":{\"source\":\"http://${var.manager_ip}:8080/master.ign\"}},\"version\":\"3.1.0\"}}"

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.name}-control-plane-${count.index + 1}"
  }

}

# resource "aws_instance" "worker" {
#   depends_on = [ var.finish_mgr, var.sgw_instance ]
#   count         = var.worker_count
#   ami           = var.RHCOS
#   instance_type = var.ocp_instance
#   subnet_id     = var.private_subnet_id
#   private_ip    = var.worker_ips[count.index]
#   security_groups = [ var.worker_sg ]
#   key_name = var.key_name

#   root_block_device {
#     volume_size = 100
#     volume_type = "gp3"
#   }

#   user_data = "{\"ignition\":{\"config\":{\"replace\":{\"source\":\"http://${var.manager_ip}:8080/worker.ign\"}},\"version\":\"3.1.0\"}}"

#   tags = {
#     Name = "${var.name}-worker-${count.index + 1}"
#   }
# }