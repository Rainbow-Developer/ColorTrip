# ColorTrip 환경별 기반 리소스
# 비용이 드는 리소스(인스턴스·Cloud SQL)는 모듈로 단계적으로 추가한다.

locals {
  # 리소스 이름 접두사: 단일 프로젝트에 dev/prod가 공존할 수 있어 환경명을 포함한다.
  name_prefix = "colortrip-${var.environment}"

  # 활성화할 GCP API
  gcp_services = [
    "compute.googleapis.com",          # Compute Engine(인스턴스·VPC·방화벽)
    "sqladmin.googleapis.com",         # Cloud SQL 관리
    "artifactregistry.googleapis.com", # Docker 이미지 저장소
    "secretmanager.googleapis.com",    # 시크릿 저장
    "iam.googleapis.com",              # 서비스 계정·권한
    "iamcredentials.googleapis.com",   # 키리스 인증(GitHub Actions WIF)
    "iap.googleapis.com",              # IAP 터널(CI 배포 SSH)
  ]

  # 앱 인스턴스 서비스 계정 권한
  app_sa_roles = [
    "roles/artifactregistry.reader",      # 이미지 pull
    "roles/cloudsql.client",              # Cloud SQL 접속(Auth Proxy)
    "roles/secretmanager.secretAccessor", # 시크릿 읽기
    "roles/logging.logWriter",            # 로그 기록
    "roles/monitoring.metricWriter",      # 메트릭 기록
  ]
}

# --- 필요한 GCP API 활성화 ---
resource "google_project_service" "services" {
  for_each           = toset(local.gcp_services)
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false # destroy 시 API를 끄지 않음(다른 리소스 영향 방지)
}

# --- 네트워크(VPC·서브넷·방화벽) ---
module "network" {
  source       = "../../modules/network"
  network_name = local.name_prefix
  region       = var.region
  subnet_cidr  = var.subnet_cidr

  depends_on = [google_project_service.services]
}

# --- 인스턴스용 서비스 계정 ---
resource "google_service_account" "app" {
  account_id   = "${local.name_prefix}-app"
  display_name = "ColorTrip 앱 인스턴스 서비스 계정 (${var.environment})"
}

resource "google_project_iam_member" "app" {
  for_each = toset(local.app_sa_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.app.email}"
}

# --- Artifact Registry(Docker 이미지 저장소) ---
resource "google_artifact_registry_repository" "docker" {
  location      = var.region
  repository_id = local.name_prefix
  format        = "DOCKER"
  description   = "ColorTrip 컨테이너 이미지 (${var.environment})"

  depends_on = [google_project_service.services]
}

# --- Compute Engine 인스턴스(FE+BE Docker 호스트) ---
module "compute" {
  source                = "../../modules/compute"
  name                  = "${local.name_prefix}-app"
  region                = var.region
  zone                  = var.zone
  machine_type          = var.instance_machine_type
  disk_gb               = var.instance_disk_gb
  subnetwork            = module.network.subnet_id
  service_account_email = google_service_account.app.email
  tags                  = ["ssh", "web"]

  depends_on = [google_project_service.services]
}

# --- Cloud SQL (PostgreSQL) ---
module "database" {
  source              = "../../modules/database"
  name                = "${local.name_prefix}-db"
  region              = var.region
  tier                = var.db_tier
  db_version          = var.db_version
  disk_gb             = var.db_disk_gb
  database_name       = var.db_name
  user_name           = var.db_user
  deletion_protection = false # dev: 재생성 편하게

  depends_on = [google_project_service.services]
}
