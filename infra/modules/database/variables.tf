variable "name" {
  description = "Cloud SQL 인스턴스 이름"
  type        = string
}

variable "region" {
  description = "리전"
  type        = string
}

variable "tier" {
  description = "머신 티어(예: db-g1-small)"
  type        = string
}

variable "db_version" {
  description = "PostgreSQL 버전"
  type        = string
  default     = "POSTGRES_16"
}

variable "disk_gb" {
  description = "디스크 크기(GB)"
  type        = number
  default     = 10
}

variable "database_name" {
  description = "애플리케이션 데이터베이스 이름"
  type        = string
}

variable "user_name" {
  description = "애플리케이션 DB 유저"
  type        = string
}

variable "deletion_protection" {
  description = "terraform destroy 보호 여부"
  type        = bool
  default     = true
}

variable "point_in_time_recovery" {
  description = "PITR(WAL) 사용 — 비용 증가, dev는 기본 off"
  type        = bool
  default     = false
}
