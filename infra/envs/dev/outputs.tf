output "network_name" {
  description = "VPC 네트워크 이름"
  value       = module.network.network_name
}

output "subnet_name" {
  description = "서브넷 이름"
  value       = module.network.subnet_name
}

output "app_service_account" {
  description = "앱 인스턴스 서비스 계정 이메일"
  value       = google_service_account.app.email
}

output "artifact_registry_repo" {
  description = "Artifact Registry Docker 저장소 경로"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}"
}

output "instance_name" {
  description = "Compute Engine 인스턴스 이름"
  value       = module.compute.name
}

output "instance_external_ip" {
  description = "인스턴스 고정 외부 IP"
  value       = module.compute.external_ip
}

output "cloud_sql_connection_name" {
  description = "Cloud SQL 연결 이름(PROJECT:REGION:INSTANCE) — Auth Proxy용"
  value       = module.database.connection_name
}

output "cloud_sql_instance" {
  description = "Cloud SQL 인스턴스 이름"
  value       = module.database.instance_name
}

output "db_password_secret" {
  description = "DB 비밀번호가 저장된 Secret Manager 시크릿 ID"
  value       = module.database.password_secret_id
}
