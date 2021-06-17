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