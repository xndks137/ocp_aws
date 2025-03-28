resource "aws_security_group" "database" {
  name_prefix = "database-sg-"
  description = "Database Security Group"
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
    Name = "${var.name}-database-sg"
  }
}

resource "aws_instance" "masterDB" {
  ami             = var.AL2023
  instance_type   = var.server_instance
  subnet_id       = var.private_subnet_id
  private_ip      = var.db_ips[0]
  security_groups = [aws_security_group.database.id]
  key_name        = var.key_name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = base64encode(file("${path.module}/master_db.sh"))

  tags = {
    Name = "${var.name}-db-0"
  }
}

resource "aws_instance" "slaveDB" {
  ami             = var.AL2023
  instance_type   = var.server_instance
  subnet_id       = var.private_subnet_id
  private_ip      = var.db_ips[1]
  security_groups = [aws_security_group.database.id]
  key_name        = var.key_name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = base64encode(file("${path.module}/slave_db.sh"))

  tags = {
    Name = "${var.name}-db-1"
  }
}