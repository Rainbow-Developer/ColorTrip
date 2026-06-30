# VPC·서브넷·방화벽 규칙

resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.network_name}-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
}

# IAP를 통한 SSH만 허용(공인 22번 포트를 외부에 노출하지 않음)
resource "google_compute_firewall" "allow_ssh_iap" {
  name          = "${var.network_name}-allow-ssh-iap"
  network       = google_compute_network.vpc.name
  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"] # GCP IAP 대역
  target_tags   = ["ssh"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# 웹 트래픽(HTTP/HTTPS) 공개 허용
resource "google_compute_firewall" "allow_web" {
  name          = "${var.network_name}-allow-web"
  network       = google_compute_network.vpc.name
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}
