module "route53" {
  source = "./modules/route53"
  cluster_name = var.cluster_name
  zone_id = var.zone_id
  domain_name = var.domain_name
  lb_public_ip = module.instances.lb_public_ip
}

module "network" {
  source = "./modules/network"
  vpc_cidr = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  region = var.region
  domain_name = var.domain_name
  cluster_name = var.cluster_name
}

module "security_gateway" {
  source = "./modules/security_gateway"
  vpc_id = module.network.vpc_id
  vpc_cidr_block = var.vpc_cidr
  public_subnet_id = module.network.public_subnet_id
  private_route_table_ids = [module.network.private_rt_id]
  ami_id = var.AL2023
  instance_type = var.server_instance
  key_name = var.key_name
  local_cidr_block = var.aws_cidr_block
  route_table_id = var.route_table_id
  aws_vpc_id = var.aws_vpc_id
}

module "instances" {
  depends_on = [ module.security_gateway ]
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
  manager_sg = module.network.mgr_sg_id
  lb_sg = module.network.lb_sg_id
  dns_sg = module.network.dns_sg_id
  bootstrap_sg = module.network.bootstrap_sg_id
  master_sg = module.network.master_sg_id
  worker_sg = module.network.worker_sg_id
  RHCOS = var.RHCOS
  AL2023 = var.AL2023
  key_name = var.key_name
  pullSecret = var.pullSecret
  ocp_instance = var.ocp_instance
  server_instance = var.server_instance
  cluster_name = var.cluster_name
  domain_name = var.domain_name
  ec2_ssh_key = var.ec2_key_file
  sgw_instance_id = module.security_gateway.sgw_instance_id
}

module "nfs_server" {
  depends_on = [ module.security_gateway ]
  source = "./modules/storage"  # 모듈 경로 지정
  vpc_id              = module.network.vpc_id
  subnet_id           = module.network.private_subnet_id
  key_name            = var.key_name
  instance_type       = var.server_instance
  data_volume_size    = var.data_volume_size
  cluster_name = var.cluster_name
  ami_id = var.AL2023
  nfs_ip = var.nfs_ip
  nfs_share_path = var.nfs_share_path
  vpc_cidr = var.vpc_cidr
  pri_sub_cidr = var.private_subnet_cidr
}
