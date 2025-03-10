output "sgw_instance_id" {
  description = "SGW 인스턴스 ID"
  value       = aws_instance.sgw_instance.id
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

output "customer_gateway_id" {
  description = "생성된 고객 게이트웨이 ID"
  value       = aws_customer_gateway.sgw_cgw.id
}

output "vpn_gateway_id" {
  description = "생성된 가상 프라이빗 게이트웨이 ID"
  value       = aws_vpn_gateway.sgw_vgw.id
}

output "vpn_connection_id" {
  description = "생성된 VPN 연결 ID"
  value       = aws_vpn_connection.sgw_vpn.id
}

output "tunnel1_address" {
  description = "VPN 터널 1 주소"
  value       = aws_vpn_connection.sgw_vpn.tunnel1_address
}

output "tunnel2_address" {
  description = "VPN 터널 2 주소"
  value       = aws_vpn_connection.sgw_vpn.tunnel2_address
}

output "tunnel1_preshared_key" {
  description = "VPN 터널 1 사전 공유 키"
  value       = aws_vpn_connection.sgw_vpn.tunnel1_preshared_key
  sensitive   = true
}

output "tunnel2_preshared_key" {
  description = "VPN 터널 2 사전 공유 키"
  value       = aws_vpn_connection.sgw_vpn.tunnel2_preshared_key
  sensitive   = true
}

output "tunnel1_inside_cidr" {
  description = "VPN 터널 1 내부 CIDR"
  value       = aws_vpn_connection.sgw_vpn.tunnel1_inside_cidr
}

output "tunnel2_inside_cidr" {
  description = "VPN 터널 2 내부 CIDR"
  value       = aws_vpn_connection.sgw_vpn.tunnel2_inside_cidr
}