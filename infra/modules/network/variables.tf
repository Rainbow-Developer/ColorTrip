variable "network_name" {
  description = "VPC 네트워크 이름"
  type        = string
}

variable "region" {
  description = "서브넷 리전"
  type        = string
}

variable "subnet_cidr" {
  description = "서브넷 CIDR"
  type        = string
}
