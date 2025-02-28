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

resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_vpc_dhcp_options" "okd_dns_resolver" {
  domain_name_servers = var.dns_servers
}

resource "aws_vpc_dhcp_options_association" "okd_dns_resolver" {
  vpc_id          = aws_vpc.main.id
  dhcp_options_id = aws_vpc_dhcp_options.okd_dns_resolver.id
}

resource "aws_security_group" "master_sg" {
  name        = "okd_master_sg"
  description = "Allow Ports for OKD master"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "okd_master_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.master_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}
resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.master_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}
resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.master_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}
resource "aws_vpc_security_group_ingress_rule" "okd_6443" {
  security_group_id = aws_security_group.master_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 6443
  ip_protocol       = "tcp"
  to_port           = 6443
}
resource "aws_vpc_security_group_ingress_rule" "okd_22623" {
  security_group_id = aws_security_group.master_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22623
  ip_protocol       = "tcp"
  to_port           = 22623
}
resource "aws_vpc_security_group_ingress_rule" "okd_1936" {
  security_group_id = aws_security_group.master_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 1936
  ip_protocol       = "tcp"
  to_port           = 1936
}
resource "aws_vpc_security_group_ingress_rule" "okd_8080" {
  security_group_id = aws_security_group.master_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 8080
  ip_protocol       = "tcp"
  to_port           = 8080
}
resource "aws_vpc_security_group_ingress_rule" "okd_53" {
  security_group_id = aws_security_group.master_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 53
  ip_protocol       = "udp"
  to_port           = 53
}

resource "aws_vpc_security_group_egress_rule" "okd_sg_egress" {
  security_group_id = aws_security_group.master_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
