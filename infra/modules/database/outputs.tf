output "connection_name" {
  description = "Cloud SQL 연결 이름(PROJECT:REGION:INSTANCE) — Auth Proxy용"
  value       = google_sql_database_instance.pg.connection_name
}

output "instance_name" {
  value = google_sql_database_instance.pg.name
}

output "public_ip" {
  value = google_sql_database_instance.pg.public_ip_address
}

output "database_name" {
  value = google_sql_database.app.name
}

output "user_name" {
  value = google_sql_user.app.name
}

output "password_secret_id" {
  description = "DB 비밀번호가 저장된 Secret Manager 시크릿 ID"
  value       = google_secret_manager_secret.db_password.secret_id
}
