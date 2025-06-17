terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# Enable necessary APIs
resource "google_project_service" "services" {
  for_each = toset([
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "storage.googleapis.com",
    "cloudvision.googleapis.com",
    "firestore.googleapis.com",
    "pubsub.googleapis.com",
    "apigateway.googleapis.com"
  ])
  service            = each.key
  disable_on_destroy = false
}
