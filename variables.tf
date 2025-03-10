variable "region" {
  default = "ap-northeast-2"
}
variable "vpc_cidr" {
  default = "192.168.0.0/16"
}
variable "public_subnet_cidr" {
  default = "192.168.0.0/20"
}
variable "private_subnet_cidr" {
  default = "192.168.128.0/20"
}
variable "manager_ip" {
  default = "192.168.10.10"
}
variable "lb_ip" {
  default = "192.168.10.20"
}
variable "dns_ip" {
  default = "192.168.10.30"
}
variable "bootstrap_ip" {
  default = "192.168.128.5"
}
variable "control_plane_ips" {
  default = ["192.168.128.10", "192.168.128.11", "192.168.128.12"]
}
variable "worker_ips" {
  default = ["192.168.128.50", "192.168.128.51", "192.168.128.52"]
}
variable "nfs_ip" {
  default = "192.168.128.100"
}
variable "db_ips" {
  default = ["192.168.128.110", "192.168.128.111"]
}
variable "RHCOS" {
  description = "RHCOS ami ID"
  default = "ami-09cfc5a33f840ce70"
}
variable "AL2023" {
  description = "Amazon Linux ami ID"
  default = "ami-075e056c0f3d02523"
}
variable "key_name" {
  default = "okd_key_pair"
  description = "Instance key pair"
}
variable "pullSecret" {
  type = string
}
variable "ec2_key_file" {
  description = "SSH private key for EC2 instance"
  type = string
}
variable "ocp_instance" {
  default = "m6i.xlarge"
  description = "Instance type for create OCP"
}
variable "server_instance" {
  default = "m6i.large"
  description = "Instance type for create servers"
}
variable "zone_id" {
  default = "Z00953263JPNGDD7UHSTQ"
}
variable "cluster_name" {
  default = "ocp4"
}
variable "domain_name" {
  default = "xndks.xyz"
}
variable "nfs_share_path" {
  default = "/data/nfs-ocp"
}
variable "data_volume_size" {
  default = 200
}
variable "aws_cidr_block" {
  description = "AWS CIDR 블록"
  type        = string
}
variable "aws_vpc_id" {
  description = "AWS VPC id"
  type        = string
}
variable "route_table_id" {
  description = "VGW 라우팅 전파를 활성화할 라우팅 테이블 ID"
  type        = string
}
