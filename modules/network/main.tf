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

resource "aws_security_group" "pub_sg" {
  name        = "pub_sg"
  description = "Allow specific ports for OKD master"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "pub_sg"
  }
}

resource "aws_security_group_rule" "pub_ingress_rules" {
  type        = "ingress"
  from_port   = each.value.port
  to_port     = each.value.port
  protocol    = each.value.protocol
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.pub_sg.id

  for_each = {
    ssh     = { port = 22, protocol = "tcp" }
    https   = { port = 443, protocol = "tcp" }
    http    = { port = 80, protocol = "tcp" }
    okd_6443 = { port = 6443, protocol = "tcp" }
    okd_22623 = { port = 22623, protocol = "tcp" }
    okd_1936 = { port = 1936, protocol = "tcp" }
    okd_8080 = { port = 8080, protocol = "tcp" }
    okd_53   = { port = 53, protocol = "udp" }
  }
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
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 19531
    to_port     = 19531
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "master" {
  name_prefix = "master-sg-"
  description = "Cluster Master Security Group"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 22623
    to_port     = 22623
    protocol    = "tcp"
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
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
}

# 마스터 보안 그룹 규칙
resource "aws_security_group_rule" "master_ingress_rules" {
  for_each = {
    etcd              = { from_port = 2379, to_port = 2380, protocol = "tcp" }
    vxlan             = { from_port = 4789, to_port = 4789, protocol = "udp" }
    geneve            = { from_port = 6081, to_port = 6081, protocol = "udp" }
    ipsec_ike         = { from_port = 500, to_port = 500, protocol = "udp" }
    ipsec_nat         = { from_port = 4500, to_port = 4500, protocol = "udp" }
    ipsec_esp         = { from_port = -1, to_port = -1, protocol = "50" }
    internal_tcp      = { from_port = 9000, to_port = 9999, protocol = "tcp" }
    internal_udp      = { from_port = 9000, to_port = 9999, protocol = "udp" }
    kube              = { from_port = 10250, to_port = 10259, protocol = "tcp" }
    ingress_services  = { from_port = 30000, to_port = 32767, protocol = "tcp" }
    ingress_services_udp = { from_port = 30000, to_port = 32767, protocol = "udp" }
  }

  type                     = "ingress"
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  source_security_group_id = aws_security_group.master.id
  security_group_id        = aws_security_group.master.id
}

# 워커 보안 그룹 규칙
resource "aws_security_group_rule" "worker_ingress_rules" {
  for_each = {
    vxlan             = { from_port = 4789, to_port = 4789, protocol = "udp" }
    geneve            = { from_port = 6081, to_port = 6081, protocol = "udp" }
    ipsec_ike         = { from_port = 500, to_port = 500, protocol = "udp" }
    ipsec_nat         = { from_port = 4500, to_port = 4500, protocol = "udp" }
    ipsec_esp         = { from_port = -1, to_port = -1, protocol = "50" }
    internal_tcp      = { from_port = 9000, to_port = 9999, protocol = "tcp" }
    internal_udp      = { from_port = 9000, to_port = 9999, protocol = "udp" }
    kube              = { from_port = 10250, to_port = 10250, protocol = "tcp" }
    ingress_services  = { from_port = 30000, to_port = 32767, protocol = "tcp" }
    ingress_services_udp = { from_port = 30000, to_port = 32767, protocol = "udp" }
  }

  type                     = "ingress"
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  source_security_group_id = aws_security_group.worker.id
  security_group_id        = aws_security_group.worker.id
}

resource "aws_eip" "nat_eip" {
  vpc   = true

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