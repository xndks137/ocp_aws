resource "aws_security_group" "gitea" {
  name_prefix = "gitea-sg-"
  description = "Gitea Security Group"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-gitea-sg"
  }
}

resource "aws_instance" "gitea" {
  ami             = var.AL2023
  instance_type   = var.server_instance
  subnet_id       = var.private_subnet_id
  private_ip      = var.gitea_ip
  security_groups = [aws_security_group.gitea.id]
  key_name        = var.key_name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = base64encode(file("${path.module}/gitea.sh"))

  tags = {
    Name = "${var.name}-gitea"
  }
}
