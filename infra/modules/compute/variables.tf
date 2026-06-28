variable "name" {
  description = "인스턴스 이름"
  type        = string
}

variable "region" {
  description = "고정 IP 리전"
  type        = string
}

variable "zone" {
  description = "인스턴스 영역(zone)"
  type        = string
}

variable "machine_type" {
  description = "머신 타입"
  type        = string
}

variable "disk_gb" {
  description = "부팅 디스크 크기(GB)"
  type        = number
  default     = 20
}

variable "image" {
  description = "부팅 이미지(project/family)"
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2204-lts"
}

variable "subnetwork" {
  description = "연결할 서브넷"
  type        = string
}

variable "service_account_email" {
  description = "부착할 서비스 계정 이메일"
  type        = string
}

variable "tags" {
  description = "네트워크 태그(방화벽 매칭)"
  type        = list(string)
  default     = []
}
