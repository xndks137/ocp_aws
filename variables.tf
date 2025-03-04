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
  default = ["192.168.128.50", "192.168.128.51"]
}

variable "ami_id" {
  description = "RHCOS ami ID"
  default = "ami-09cfc5a33f840ce70"
}

variable "dns_servers" {
  description = "DNS Server for OKD Cluster"
  default = ["192.168.10.30","8.8.8.8"]
}

variable "key_name" {
  default = "okd_key_pair"
  description = "Instance key pair"
}

variable "pullSecret" {
 type = string
}
