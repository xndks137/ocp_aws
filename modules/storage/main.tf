# NFS 서버 보안 그룹
resource "aws_security_group" "nfs_sg" {
  name        = "nfs-sg"
  description = "Security group for NFS server"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
    description = "All port for private"
  }

  # 모든 아웃바운드 트래픽 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.name}-nfs-sg"
  }
}

# NFS 서버용 데이터 볼륨
resource "aws_ebs_volume" "nfs_data" {
  availability_zone = data.aws_subnet.selected.availability_zone
  size              = var.data_volume_size
  type              = "gp3"
  tags = {
    Name = "${var.name}-nfs-volume"
  }
}

data "aws_subnet" "selected" {
  id = var.subnet_id
}

# NFS 서버 EC2 인스턴스
resource "aws_instance" "nfs_server" {
  depends_on             = [aws_ebs_volume.nfs_data]
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  private_ip             = var.nfs_ip
  vpc_security_group_ids = [aws_security_group.nfs_sg.id]

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = base64encode(templatefile("${path.module}/userdata.tpl", {
    nfs_share_path = var.nfs_share_path,
    pri_sub_cidr   = var.pri_sub_cidr
  }))

  tags = {
    Name = "${var.name}-nfs"
  }
}

# 데이터 볼륨 연결
resource "aws_volume_attachment" "nfs_data_attachment" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.nfs_data.id
  instance_id = aws_instance.nfs_server.id
}
