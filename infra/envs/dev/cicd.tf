# CI/CD — GitHub Actions가 키 없이(WIF) GCP에 인증하고 배포한다.

locals {
  # WIF로 신뢰할 GitHub 저장소 (이 repo에서 온 토큰만 허용)
  github_repo = "Rainbow-Developer/ColorTrip"
}

# 배포용 서비스 계정 (GitHub Actions가 임퍼소네이션)
resource "google_service_account" "deployer" {
  account_id   = "${local.name_prefix}-deployer"
  display_name = "ColorTrip CI/CD 배포자 (${var.environment})"
}

locals {
  deployer_roles = [
    "roles/artifactregistry.writer",    # 이미지 push
    "roles/iap.tunnelResourceAccessor", # IAP 터널로 SSH
    "roles/compute.osAdminLogin",       # OS Login + sudo (docker 실행)
    "roles/compute.viewer",             # 인스턴스 조회(ssh/scp 대상 resolve)
  ]
}

resource "google_project_iam_member" "deployer" {
  for_each = toset(local.deployer_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.deployer.email}"
}

# --- Workload Identity Federation (GitHub OIDC) ---
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "${local.name_prefix}-gh-pool"
  display_name              = "GitHub Actions (${var.environment})"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # 우리 repo에서 발급된 토큰만 허용
  attribute_condition = "assertion.repository == \"${local.github_repo}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# 이 repo의 GitHub Actions가 배포자 SA를 임퍼소네이션하도록 허용
resource "google_service_account_iam_member" "deployer_wif" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${local.github_repo}"
}
