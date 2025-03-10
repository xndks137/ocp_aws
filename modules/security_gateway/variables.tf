variable "name" {
  description = "리소스 이름 접두사"
  type        = string
  default     = "ocp"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr_block" {
  description = "VPC CIDR 블록"
  type        = string
}

variable "public_subnet_id" {
  description = "SGW 인스턴스가 배치될 퍼블릭 서브넷 ID"
  type        = string
}

variable "private_route_table_ids" {
  description = "NAT 라우팅을 위한 프라이빗 라우트 테이블 ID 목록"
  type        = list(string)
}

variable "ami_id" {
  description = "SGW 인스턴스용 AMI ID (Amazon Linux 2023 권장)"
  type        = string
}

variable "instance_type" {
  description = "SGW 인스턴스 타입"
  type        = string
}

variable "key_name" {
  description = "SSH 키 이름"
  type        = string
}

variable "static_routes_only" {
  description = "정적 라우팅만 사용할지 여부 (true: 정적, false: 동적(BGP))"
  type        = bool
  default     = true
}

variable "local_cidr_block" {
  description = "로컬(AWS) CIDR 블록 목록"
  type        = string
}

variable "route_table_id" {
  description = "VGW 라우팅 전파를 활성화할 라우팅 테이블 ID"
  type        = string
}

variable "aws_vpc_id" {
  description = "AWS VPC ID"
  type        = string
}