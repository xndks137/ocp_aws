resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "okd4-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "okd4-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone = "${var.region}a"
  tags = {
    Name = "okd4-public-subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_cidr
  availability_zone = "${var.region}a"
  tags = {
    Name = "okd4-private-subnet"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "okd4-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "okd4-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_rt.id
}


# resource "aws_vpc_dhcp_options" "okd_dns_resolver" {
#   domain_name_servers = var.dns_servers
# }

# resource "aws_vpc_dhcp_options_association" "okd_dns_resolver" {
#   vpc_id          = aws_vpc.main.id
#   dhcp_options_id = aws_vpc_dhcp_options.okd_dns_resolver.id
# }


resource "aws_security_group" "pub_sg" {
  name        = "pub_sg"
  description = "Allow specific ports for OKD master"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "pub_sg"
  }
}

resource "aws_security_group_rule" "pub_ingress_rules" {
  # type        = "ingress"
  # from_port   = each.value.port
  # to_port     = each.value.port
  # protocol    = each.value.protocol
  # cidr_blocks = ["0.0.0.0/0"]
  # security_group_id = aws_security_group.pub_sg.id

  # for_each = {
  #   ssh     = { port = 22, protocol = "tcp" }
  #   https   = { port = 443, protocol = "tcp" }
  #   http    = { port = 80, protocol = "tcp" }
  #   okd_6443 = { port = 6443, protocol = "tcp" }
  #   okd_22623 = { port = 22623, protocol = "tcp" }
  #   okd_1936 = { port = 1936, protocol = "tcp" }
  #   okd_8080 = { port = 8080, protocol = "tcp" }
  #   okd_53   = { port = 53, protocol = "udp" }
  # }

  type        = "ingress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.pub_sg.id
}

resource "aws_security_group_rule" "pub_egress_rule" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.pub_sg.id
}

# 부트스트랩 보안 그룹
resource "aws_security_group" "bootstrap" {
  name        = "bootstrap-sg"
  description = "Cluster Bootstrap Security Group"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }
}

resource "aws_security_group" "master" {
  name_prefix = "master-sg-"
  description = "Cluster Master Security Group"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }
}

resource "aws_security_group" "worker" {
  name_prefix = "worker-sg-"
  description = "Cluster Worker Security Group"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }
}

# 마스터 보안 그룹 규칙
resource "aws_security_group_rule" "master_ingress_rules" {
  type                     = "ingress"
  protocol                 = "-1"
  to_port = 0
  from_port = 0
  source_security_group_id = aws_security_group.master.id
  security_group_id        = aws_security_group.master.id
}

# 워커 보안 그룹 규칙
resource "aws_security_group_rule" "worker_ingress_rules" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.worker.id
  security_group_id        = aws_security_group.worker.id
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "NAT-EIP"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "gw NAT"
  }
}
