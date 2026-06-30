# Compute Engine 인스턴스 + 고정 외부 IP
# FE·BE 컨테이너를 Docker로 구동하는 단일 호스트.

# 고정 외부 IP (도메인 연결 대비, 실행 중 인스턴스에 붙어 있으면 무료)
resource "google_compute_address" "ext" {
  name   = "${var.name}-ip"
  region = var.region
}

resource "google_compute_instance" "vm" {
  name         = var.name
  zone         = var.zone
  machine_type = var.machine_type
  tags         = var.tags

  boot_disk {
    initialize_params {
      image = var.image
      size  = var.disk_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = var.subnetwork

    # 공인 IP(고정) 부착
    access_config {
      nat_ip = google_compute_address.ext.address
    }
  }

  # 인스턴스에 부착할 서비스 계정 (레지스트리 pull·Cloud SQL·Secret 접근)
  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  # OS Login 활성화 — CI 배포자 SA가 IAP SSH로 접속(키 없이 IAM 제어)
  metadata = {
    enable-oslogin = "TRUE"
  }

  # 부팅 시 Docker·compose 설치
  metadata_startup_script = file("${path.module}/startup.sh")

  # 머신 타입·디스크 변경 시 인스턴스를 멈췄다 다시 띄울 수 있게 허용
  allow_stopping_for_update = true
}
