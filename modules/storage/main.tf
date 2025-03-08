# NFS 서버 보안 그룹
resource "aws_security_group" "nfs_sg" {
  name        = "nfs-sg"
  description = "Security group for NFS server"
  vpc_id      = var.vpc_id

  # SSH 접속 허용
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "SSH access"
  }

  # NFS v4 포트
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "NFS port"
  }

  # NFS v4 UDP
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
    description = "NFS port (UDP)"
  }

  # 추가 NFS 포트 (선택적)
  ingress {
    from_port   = 111
    to_port     = 111
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "NFS portmapper"
  }

  ingress {
    from_port   = 111
    to_port     = 111
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
    description = "NFS portmapper (UDP)"
  }

  # 동적 포트 범위
  ingress {
    from_port   = 32760
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "NFS dynamic ports"
  }

  ingress {
    from_port   = 32760
    to_port     = 32767
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
    description = "NFS dynamic ports (UDP)"
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
      Name = "${var.cluster_name}-nfs-sg"
  }
}

# NFS 서버용 데이터 볼륨
resource "aws_ebs_volume" "nfs_data" {
  availability_zone = data.aws_subnet.selected.availability_zone
  size              = var.data_volume_size
  type              = "gp3"
  tags = {
    Name = "${var.cluster_name}-nfs-volume"
  }
}

data "aws_subnet" "selected" {
  id = var.subnet_id
}

# NFS 서버 EC2 인스턴스
resource "aws_instance" "nfs_server" {
  depends_on = [ aws_ebs_volume.nfs_data ]
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  private_ip             = var.nfs_ip
  vpc_security_group_ids = [aws_security_group.nfs_sg.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = base64encode(templatefile("${path.module}/userdata.tpl", {
    nfs_share_path = var.nfs_share_path,
    pri_sub_cidr = var.pri_sub_cidr
  }))

  tags = {
    Name = "${var.cluster_name}-nfs"
  }
}

# 데이터 볼륨 연결
resource "aws_volume_attachment" "nfs_data_attachment" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.nfs_data.id
  instance_id = aws_instance.nfs_server.id
}
