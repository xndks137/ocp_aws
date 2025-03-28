output "sgw_instance" {
  description = "SGW 인스턴스 ID"
  value       = aws_instance.sgw_instance
}

output "sgw_private_ip" {
  description = "SGW 인스턴스 프라이빗 IP"
  value       = aws_network_interface.sgw_eni.private_ip
}

output "sgw_public_ip" {
  description = "SGW 인스턴스 퍼블릭 IP"
  value       = aws_eip.sgw_eip.public_ip
}

output "sgw_security_group_id" {
  description = "SGW 보안 그룹 ID"
  value       = aws_security_group.sgw_sg.id
}
