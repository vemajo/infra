#Tests
variable "project_name" {}

provider "google" {
  project = "${var.project_name}-dev"
  region  = "europe-north1"
}

terraform {
  backend "gcs" {
    bucket = "vemajo_iac_bucket"
    prefix = "terraform/gke/cluster"
  }
}

resource "google_compute_subnetwork" "custom" {
  name          = "dev-subnetwork"
  ip_cidr_range = "10.2.0.0/16"
  region        = "europe-north1"
  network       = google_compute_network.custom.id
  secondary_ip_range {
    range_name    = "services-range"
    ip_cidr_range = "192.168.0.0/22"
  }

  secondary_ip_range {
    range_name    = "pod-ranges"
    ip_cidr_range = "192.168.64.0/22"
  }
}

resource "google_compute_network" "custom" {
  name                    = "dev-network"
  auto_create_subnetworks = false
}

resource "google_service_account" "default" {
  account_id   = "${var.project_name}-gke-service-account"
  display_name = "${var.project_name}-gke-acct"
}

resource "google_container_cluster" "primary" {
  name     = "${var.project_name}-cluster"
  location = "europe-north1"

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
  networking_mode          = "VPC_NATIVE"
  network                  = google_compute_network.custom.id
  subnetwork               = google_compute_subnetwork.custom.id

  ip_allocation_policy {
    cluster_secondary_range_name  = "services-range"
    services_secondary_range_name = google_compute_subnetwork.custom.secondary_ip_range.1.range_name
  }
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "${var.project_name}-node-pool"
  location   = "europe-north1"
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = "e2-small"

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.default.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}
