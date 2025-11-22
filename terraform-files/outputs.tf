output "network_name" {
  value = google_compute_network.vpc.name
}

output "public_subnet" {
  value = google_compute_subnetwork.subnet_public.name
}

output "private_subnet" {
  value = google_compute_subnetwork.subnet_private.name
}
