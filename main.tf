module "route53" {
  source       = "./modules/route53"
  cluster_name = var.cluster_name
  zone_id      = var.zone_id
  domain_name  = var.domain_name
  lb_public_ip = module.instances.lb_public_ip
}

module "network" {
  source              = "./modules/network"
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  region              = var.region
  domain_name         = var.domain_name
  name                = var.project_name
}

module "security_gateway" {
  source                 = "./modules/security_gateway"
  vpc_id                 = module.network.vpc_id
  name                   = var.project_name
  vpc_cidr_block         = var.vpc_cidr
  public_subnet_id       = module.network.public_subnet_id
  private_route_table_id = module.network.private_rt_id
  public_route_table_id  = module.network.public_rt_id
  ami_id                 = var.AL2023
  instance_type          = var.server_instance
  key_name               = var.key_name
  nat_ip                 = var.nat_ip
}

module "instances" {
  source              = "./modules/instances"
  vpc_id              = module.network.vpc_id
  public_subnet_id    = module.network.public_subnet_id
  manager_ip          = var.manager_ip
  lb_ip               = var.lb_ip
  dns_ip              = var.dns_ip
  monitor_ip          = var.monitor_ip
  bootstrap_ip        = var.bootstrap_ip
  control_plane_ips   = var.control_plane_ips
  worker_ips          = var.worker_ips
  db_ips              = var.db_ips
  manager_sg          = module.network.mgr_sg_id
  lb_sg               = module.network.lb_sg_id
  dns_sg              = module.network.dns_sg_id
  monitor_sg          = module.network.monitor_sg_id
  AL2023              = var.AL2023
  key_name            = var.key_name
  pullSecret          = var.pullSecret
  server_instance     = var.server_instance
  name                = var.project_name
  cluster_name        = var.cluster_name
  domain_name         = var.domain_name
  ec2_ssh_key         = var.ec2_ssh_key
  control_plane_count = var.master_count
  worker_count        = var.worker_count
  nat_ip              = var.nat_ip
  nfs_ip              = var.nfs_ip
  gitea_ip            = var.gitea_ip
  # waf_ip            = var.waf_ip
  # waf_sg = module.network.waf_sg_id
}

module "openshift" {
  depends_on          = [module.security_gateway, module.instances]
  source              = "./modules/openshift"
  private_subnet_id   = module.network.private_subnet_id
  manager_ip          = var.manager_ip
  bootstrap_ip        = var.bootstrap_ip
  control_plane_ips   = var.control_plane_ips
  worker_ips          = var.worker_ips
  bootstrap_sg        = module.network.bootstrap_sg_id
  master_sg           = module.network.master_sg_id
  worker_sg           = module.network.worker_sg_id
  RHCOS               = var.RHCOS
  key_name            = var.key_name
  pullSecret          = var.pullSecret
  ocp_instance        = var.ocp_instance
  name                = var.project_name
  cluster_name        = var.cluster_name
  domain_name         = var.domain_name
  ec2_ssh_key         = var.ec2_ssh_key
  control_plane_count = var.master_count
  worker_count        = var.worker_count
  finish_mgr          = module.instances.null_resource
  sgw_instance        = module.security_gateway.sgw_instance
}

module "nfs_server" {
  depends_on       = [module.security_gateway]
  source           = "./modules/storage" # 모듈 경로 지정
  vpc_id           = module.network.vpc_id
  subnet_id        = module.network.private_subnet_id
  key_name         = var.key_name
  instance_type    = var.server_instance
  data_volume_size = var.data_volume_size
  name             = var.project_name
  ami_id           = var.AL2023
  nfs_ip           = var.nfs_ip
  nfs_share_path   = var.nfs_share_path
  vpc_cidr         = var.vpc_cidr
  pri_sub_cidr     = var.private_subnet_cidr
}

module "db_server" {
  depends_on        = [module.security_gateway]
  source            = "./modules/database"
  vpc_id            = module.network.vpc_id
  vpc_cidr          = var.vpc_cidr
  name              = var.project_name
  private_subnet_id = module.network.private_subnet_id
  key_name          = var.key_name
  server_instance   = var.server_instance
  AL2023            = var.AL2023
  db_ips            = var.db_ips
}

module "gitea" {
  depends_on        = [module.security_gateway]
  source            = "./modules/gitea"
  vpc_id            = module.network.vpc_id
  vpc_cidr          = var.vpc_cidr
  name              = var.project_name
  private_subnet_id = module.network.private_subnet_id
  key_name          = var.key_name
  server_instance   = var.server_instance
  AL2023            = var.AL2023
  gitea_ip          = var.gitea_ip
}
