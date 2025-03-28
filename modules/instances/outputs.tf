output "lb_public_ip" {
  value = aws_instance.lb.public_ip
}
output "manager_ip" {
  value = aws_instance.manager.public_ip
}

output "null_resource" {
  value = null_resource.finish_mgr
}
