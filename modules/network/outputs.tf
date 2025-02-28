output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "pub_sg_id" {
  value = aws_security_group.pub_sg.id
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