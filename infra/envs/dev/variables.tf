variable "project_id" {
  description = "GCP 프로젝트 ID"
  type        = string
}

variable "region" {
  description = "기본 리전"
  type        = string
  default     = "asia-northeast3" # 서울
}

variable "zone" {
  description = "기본 영역(zone)"
  type        = string
  default     = "asia-northeast3-a"
}

variable "environment" {
  description = "환경 이름(dev | prod). 리소스 이름 접두사에 사용"
  type        = string
}

variable "subnet_cidr" {
  description = "서브넷 CIDR"
  type        = string
  default     = "10.10.0.0/24"
}

# --- 인스턴스 ---
variable "instance_machine_type" {
  description = "Compute Engine 머신 타입"
  type        = string
  default     = "e2-small"
}

variable "instance_disk_gb" {
  description = "부팅 디스크 크기(GB)"
  type        = number
  default     = 20
}

# --- Cloud SQL ---
variable "db_tier" {
  description = "Cloud SQL 머신 티어"
  type        = string
  default     = "db-g1-small"
}

variable "db_disk_gb" {
  description = "Cloud SQL 디스크(GB)"
  type        = number
  default     = 10
}

variable "db_version" {
  description = "PostgreSQL 버전"
  type        = string
  default     = "POSTGRES_16"
}

variable "db_name" {
  description = "애플리케이션 데이터베이스 이름"
  type        = string
  default     = "colortrip"
}

variable "db_user" {
  description = "애플리케이션 DB 유저"
  type        = string
  default     = "colortrip"
}
