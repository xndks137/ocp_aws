output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "mgr_sg_id" {
  value = aws_security_group.manager.id
}

output "lb_sg_id" {
  value = aws_security_group.lb.id
}

output "dns_sg_id" {
  value = aws_security_group.dns.id
}

output "bootstrap_sg_id" {
  value = aws_security_group.bootstrap.id
}

output "master_sg_id" {
  value = aws_security_group.master.id
}

output "worker_sg_id" {
  value = aws_security_group.worker.id
} 

output "private_rt_id" {
  value = aws_route_table.private_rt.id
}