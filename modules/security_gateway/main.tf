# Security Group for NAT/VPN instance
resource "aws_security_group" "sgw_sg" {
  name        = "${var.name}-sgw-sg"
  description = "Security group for NAT and VPN instance"
  vpc_id      = var.vpc_id

  # ingress {
  #   description = "Allow all traffic for test"
  #   from_port   = 0
  #   to_port     = 0
  #   protocol    = "-1"
  #   cidr_blocks = [ "0.0.0.0/0"]
  # }

  # VPN에서 오는 모든 트래픽 허용
  ingress {
    description = "Allow all traffic from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # 내부 네트워크에서 오는 모든 트래픽 허용
  ingress {
    description = "Allow all traffic from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr_block]
  }

  # IPsec IKE 프로토콜 허용
  ingress {
    description = "Allow IPsec IKE"
    from_port   = 500
    to_port     = 500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # IPsec NAT-T 프로토콜 허용
  ingress {
    description = "Allow IPsec NAT-T"
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ESP 프로토콜 허용
  ingress {
    description = "Allow ESP Protocol"
    from_port   = -1
    to_port     = -1
    protocol    = "50"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 모든 아웃바운드 트래픽 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-sgw-sg"
  }
}

# Network Interface for the instance
resource "aws_network_interface" "sgw_eni" {
  subnet_id         = var.public_subnet_id
  private_ips       = [var.nat_ip]
  security_groups   = [aws_security_group.sgw_sg.id]
  source_dest_check = false

  tags = {
    Name = "${var.name}-eni"
  }
}

# NAT/VPN Instance
resource "aws_instance" "sgw_instance" {
  depends_on    = [aws_network_interface.sgw_eni]
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  network_interface {
    network_interface_id = aws_network_interface.sgw_eni.id
    device_index         = 0
  }

  user_data = file("${path.module}/sgw_setup.sh")

  tags = {
    Name = "${var.name}-sgw"
  }
}

# Elastic IP for the instance
resource "aws_eip" "sgw_eip" {
  depends_on        = [aws_network_interface.sgw_eni]
  network_interface = aws_network_interface.sgw_eni.id

  tags = {
    Name = "${var.name}-sgw-eip"
  }
}

# Route from private subnets to NAT instance
resource "aws_route" "sgw_private_route" {
  route_table_id         = var.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_network_interface.sgw_eni.id
}

# resource "aws_route" "sgw_public_route" {
#   route_table_id         = var.public_route_table_id
#   destination_cidr_block = "10.0.0.0/16"
#   network_interface_id   = aws_network_interface.sgw_eni.id
# }
