terraform {
  required_version = ">= 1.8.0"

  backend "gcs" {}

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-south1"
}

module "firebase" {
  source = "../../modules/firebase"

  project_id      = var.project_id
  region          = var.region
  firestore_rules = "${path.module}/../../modules/firebase/rules/firestore.rules"
  storage_rules   = "${path.module}/../../modules/firebase/rules/storage.rules"

  firestore_indexes = [
    {
      collection = "approvals"
      fields = [
        { field_path = "status", order = "ASCENDING" },
        { field_path = "requestedAt", order = "DESCENDING" }
      ]
    },
    {
      collection = "builders"
      fields = [
        { field_path = "onboardingStatus", order = "ASCENDING" },
        { field_path = "updatedAt", order = "DESCENDING" }
      ]
    },
    {
      collection = "projects"
      fields = [
        { field_path = "visibilityStatus", order = "ASCENDING" },
        { field_path = "createdAt", order = "DESCENDING" }
      ]
    }
  ]
}

output "firestore_database" {
  value = module.firebase.firestore_database_name
}
