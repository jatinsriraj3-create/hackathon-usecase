terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ---------------------------
# Networking: VPC and subnets
# ---------------------------
resource "google_compute_network" "vpc" {
  name                    = "${var.prefix}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_subnetwork" "subnet_public" {
  name                     = "${var.prefix}-subnet-public"
  ip_cidr_range            = var.public_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.vpc.self_link
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "subnet_private" {
  name                     = "${var.prefix}-subnet-private"
  ip_cidr_range            = var.private_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.vpc.self_link
  private_ip_google_access = true
}

# Cloud Router + NAT for private egress to internet (pull images, updates)
resource "google_compute_router" "router" {
  name    = "${var.prefix}-router"
  region  = var.region
  network = google_compute_network.vpc.self_link
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.prefix}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.subnet_private.name
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

# --------------------------------
# Firewall rules (basic, ingress)
# --------------------------------
resource "google_compute_firewall" "allow_health_check" {
  name    = "${var.prefix}-fw-hc"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"] # Google LB health checks
  direction     = "INGRESS"
}

resource "google_compute_firewall" "allow_ssh_public" {
  name    = "${var.prefix}-fw-ssh-public"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.admin_cidr] # lock to your office IP range
  direction     = "INGRESS"
}

# ---------------------------
# IAM service accounts (SAs)
# ---------------------------
resource "google_service_account" "sa_ci" {
  account_id   = "${var.prefix}-ci"
  display_name = "CI/CD Service Account"
}

resource "google_service_account" "sa_deploy" {
  account_id   = "${var.prefix}-deploy"
  display_name = "Deploy Service Account"
}

# Roles for CI (push images to Artifact Registry, read/write configs)
resource "google_project_iam_member" "ci_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.sa_ci.email}"
}

resource "google_project_iam_member" "ci_viewer" {
  project = var.project_id
  role    = "roles/viewer"
  member  = "serviceAccount:${google_service_account.sa_ci.email}"
}

# Roles for deploy (manage GKE workloads)
resource "google_project_iam_member" "deploy_container_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.sa_deploy.email}"
}

resource "google_project_iam_member" "deploy_artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.sa_deploy.email}"
}

# Optionally grant Workload Identity binding later in cluster config for k8s SA mapping.

# ---------------------------
# GKE cluster (private nodes)
# ---------------------------
resource "google_container_cluster" "gke" {
  name     = "${var.prefix}-gke"
  location = var.region
  network  = google_compute_network.vpc.self_link
  subnetwork = google_compute_subnetwork.subnet_private.self_link

  release_channel {
    channel = "REGULAR"
  }

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {}

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_cidr
  }

  # Logging/Monitoring to Cloud Ops
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # Control Plane authorized networks (limit kubectl access)
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.admin_cidr
      display_name = "admin"
    }
  }

  # Security features
  binary_authorization {
    evaluation_mode = "DISABLED"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Remove default node pool; we'll manage separately
  remove_default_node_pool = true
  initial_node_count       = 1
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.prefix}-np-primary"
  location   = var.region
  cluster    = google_container_cluster.gke.name

  node_count = var.node_count

  node_config {
    machine_type = var.node_machine
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
    labels = {
      env = var.prefix
    }
    tags = ["gke-node"]
    disk_type = "pd-standard"
    disk_size_gb = 10
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# -------------------------------------------
# Artifact Registry (Docker repository for images)
# -------------------------------------------
resource "google_artifact_registry_repository" "repo" {
  location               = var.region
  repository_id          = "${var.prefix}-microservices"
  format                 = "DOCKER"
  description            = "Docker images for microservices"
  kms_key_name           = null
  cleanup_policy_dry_run = true
}

# -------------------------------------------
# Outputs helpful for CI/CD and kubectl
# -------------------------------------------
data "google_client_config" "current" {}

output "gke_cluster_name" {
  value = google_container_cluster.gke.name
}

output "gke_endpoint" {
  value = google_container_cluster.gke.endpoint
}

output "artifact_repo_path" {
  value = "${google_artifact_registry_repository.repo.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repo.repository_id}"
}

output "service_account_ci_email" {
  value = google_service_account.sa_ci.email
}

output "service_account_deploy_email" {
  value = google_service_account.sa_deploy.email
}
