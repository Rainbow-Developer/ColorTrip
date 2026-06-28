output "name" {
  value = google_compute_instance.vm.name
}

output "zone" {
  value = google_compute_instance.vm.zone
}

output "external_ip" {
  value = google_compute_address.ext.address
}
