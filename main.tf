module "network" {
  source = "./modules/network"
  vpc_cidr = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  region = var.region
  dns_servers = var.dns_servers
}

module "instances" {
  source = "./modules/instances"
  vpc_id = module.network.vpc_id
  public_subnet_id = module.network.public_subnet_id
  private_subnet_id = module.network.private_subnet_id
  manager_ip = var.manager_ip
  lb_ip = var.lb_ip
  dns_ip = var.dns_ip
  bootstrap_ip = var.bootstrap_ip
  control_plane_ips = var.control_plane_ips
  worker_ips = var.worker_ips
  security_group= module.network.security_group_id
  fcos_ami = var.FCOS
  al2023_ami = var.al2023
  key_name = var.key_name
  pullSecret = var.pullSecret
}

