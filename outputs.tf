output "nfs_server_ip" {
  description = "The private IP address of the NFS server"
  value       = module.nfs_server.nfs_server_private_ip
}

output "nfs_share_path" {
  description = "The path of the NFS share"
  value       = module.nfs_server.nfs_share_path
}

output "manager_ip" {
  value = module.instances.manager_ip
}

output "vpn_ip" {
  value = module.security_gateway.sgw_public_ip
}