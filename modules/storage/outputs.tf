output "nfs_server_id" {
  description = "The ID of the NFS server instance"
  value       = aws_instance.nfs_server.id
}

output "nfs_server_private_ip" {
  description = "The private IP address of the NFS server"
  value       = aws_instance.nfs_server.private_ip
}

output "nfs_share_path" {
  description = "The path of the NFS share"
  value       = var.nfs_share_path
}
