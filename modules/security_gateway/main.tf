# Security Group for NAT/VPN instance
resource "aws_security_group" "sgw_sg" {
  name        = "${var.name}-sgw-sg"
  description = "Security group for NAT and VPN instance"
  vpc_id      = var.vpc_id

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

  ingress {
    description = "Allow SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
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
  subnet_id       = var.public_subnet_id
  security_groups = [aws_security_group.sgw_sg.id]
  source_dest_check = false

  tags = {
    Name = "${var.name}-sgw-eni"
  }
}

# NAT/VPN Instance
resource "aws_instance" "sgw_instance" {
  depends_on = [ aws_vpn_connection.sgw_vpn ]
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  network_interface {
    network_interface_id = aws_network_interface.sgw_eni.id
    device_index         = 0
  }

  user_data = templatefile("${path.module}/sgw_setup.sh.tpl", {
    local_ip            = aws_network_interface.sgw_eni.private_ip
    local_public_ip     = aws_eip.sgw_eip.public_ip
    local_cidr          = var.vpc_cidr_block
    remote_cidr         = var.local_cidr_block
    tunnel1_address     = aws_vpn_connection.sgw_vpn.tunnel1_address
    tunnel2_address     = aws_vpn_connection.sgw_vpn.tunnel2_address
    preshared_key1       = aws_vpn_connection.sgw_vpn.tunnel1_preshared_key
    preshared_key2       = aws_vpn_connection.sgw_vpn.tunnel2_preshared_key
    tunnel1_inside_cidr = aws_vpn_connection.sgw_vpn.tunnel1_inside_cidr
    tunnel2_inside_cidr = aws_vpn_connection.sgw_vpn.tunnel2_inside_cidr
  })

  tags = {
    Name = "${var.name}-sgw"
  }
}

# Elastic IP for the instance
resource "aws_eip" "sgw_eip" {
  network_interface = aws_network_interface.sgw_eni.id
  
  tags = {
    Name = "${var.name}-sgw-eip"
  }
}

# Route from private subnets to NAT instance
resource "aws_route" "private_sgw_route" {
  count                  = length(var.private_route_table_ids)
  route_table_id         = var.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_network_interface.sgw_eni.id
}

######################  VPN 부분  ############################
# Customer Gateway
resource "aws_customer_gateway" "sgw_cgw" {
  ip_address = aws_eip.sgw_eip.public_ip  # 인스턴스의 EIP 사용
  type       = "ipsec.1"
  
  tags = {
    Name = "${var.name}-cgw"
  }
}

# Virtual Private Gateway
resource "aws_vpn_gateway" "sgw_vgw" {
  
  tags = {
    Name = "${var.name}-vgw"
  }
}

resource "aws_vpn_gateway_attachment" "vpn_attachment" {
  vpc_id         = var.aws_vpc_id
  vpn_gateway_id = aws_vpn_gateway.sgw_vgw.id
}

# Site-to-Site VPN Connection
resource "aws_vpn_connection" "sgw_vpn" {
  vpn_gateway_id      = aws_vpn_gateway.sgw_vgw.id
  customer_gateway_id = aws_customer_gateway.sgw_cgw.id
  type                = "ipsec.1"
  static_routes_only  = var.static_routes_only
  
  tags = {
    Name = "${var.name}-vpn-connection"
  }
}

# Static routes for VPN (if enabled)
resource "aws_vpn_connection_route" "vpn_routes" {  
  destination_cidr_block = var.vpc_cidr_block
  vpn_connection_id      = aws_vpn_connection.sgw_vpn.id
}

# VPC routing table propagation
resource "aws_vpn_gateway_route_propagation" "vpn_route_propagation" {
  
  vpn_gateway_id = aws_vpn_gateway.sgw_vgw.id
  route_table_id = var.route_table_id
}