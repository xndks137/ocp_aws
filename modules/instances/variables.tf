variable "vpc_id" {}
variable "public_subnet_id" {}
variable "private_subnet_id" {}
variable "manager_ip" {}
variable "lb_ip" {}
variable "dns_ip" {}
variable "bootstrap_ip" {}
variable "control_plane_ips" {}
variable "worker_ips" {}
variable "RHCOS" {}
variable "AL2023" {}
variable "pub_sg" {}
variable "bootstrap_sg" {}
variable "master_sg" {}
variable "worker_sg" {}
variable "key_name" {}
variable "pullSecret" {}
variable "bootstrap_iam" {}
variable "master_iam" {}
variable "worker_iam" {}
variable "instance_type" {}
