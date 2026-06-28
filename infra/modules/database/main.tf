# Cloud SQL (PostgreSQL) + DB·유저 + 비밀번호(Secret Manager)
# 접속은 Cloud SQL Auth Proxy로만 한다(공인 IP에 authorized_networks를 두지 않음).

# DB 유저 비밀번호 자동 생성
resource "random_password" "db" {
  length  = 24
  special = false # 연결 문자열에서 인코딩 이슈 방지(영숫자만)
}

resource "google_sql_database_instance" "pg" {
  name             = var.name
  region           = var.region
  database_version = var.db_version

  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    edition           = "ENTERPRISE"
    availability_type = "ZONAL" # dev: HA 없음
    disk_size         = var.disk_gb
    disk_type         = "PD_SSD"
    disk_autoresize   = true

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = var.point_in_time_recovery
      start_time                     = "18:00" # UTC(=03:00 KST)
    }

    ip_configuration {
      ipv4_enabled = true
      ssl_mode     = "ENCRYPTED_ONLY" # 비SSL 접속 거부(Auth Proxy는 SSL 사용)
      # authorized_networks 없음 → 직접 접속 불가, Auth Proxy(IAM)로만 접속
    }
  }
}

resource "google_sql_database" "app" {
  name     = var.database_name
  instance = google_sql_database_instance.pg.name
}

resource "google_sql_user" "app" {
  name     = var.user_name
  instance = google_sql_database_instance.pg.name
  password = random_password.db.result
}

# 비밀번호를 Secret Manager에 저장(앱은 여기서 읽음)
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.name}-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db.result
}
