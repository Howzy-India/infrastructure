terraform {
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

# ── Firebase Project ──────────────────────────────────────────────────

resource "google_firebase_project" "default" {
  provider = google-beta
  project  = var.project_id
}

# ── Firestore Database ───────────────────────────────────────────────

resource "google_firestore_database" "default" {
  provider    = google
  project     = var.project_id
  name        = "(default)"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"

  depends_on = [google_firebase_project.default]
}

# ── Firestore Security Rules ─────────────────────────────────────────

resource "google_firebaserules_ruleset" "firestore" {
  provider = google-beta
  project  = var.project_id

  source {
    files {
      name    = "firestore.rules"
      content = file(var.firestore_rules)
    }
  }

  depends_on = [google_firestore_database.default]
}

resource "google_firebaserules_release" "firestore" {
  provider     = google-beta
  project      = var.project_id
  name         = "cloud.firestore"
  ruleset_name = google_firebaserules_ruleset.firestore.name

  depends_on = [google_firebaserules_ruleset.firestore]
}

# ── Firestore Composite Indexes ──────────────────────────────────────

resource "google_firestore_index" "indexes" {
  for_each   = { for idx, i in var.firestore_indexes : "${i.collection}-${idx}" => i }
  project    = var.project_id
  database   = google_firestore_database.default.name
  collection = each.value.collection
  query_scope = each.value.query_scope

  dynamic "fields" {
    for_each = each.value.fields
    content {
      field_path   = fields.value.field_path
      order        = fields.value.order
      array_config = fields.value.array_config
    }
  }

  depends_on = [google_firestore_database.default]
}

# ── Storage Security Rules ───────────────────────────────────────────

resource "google_firebaserules_ruleset" "storage" {
  provider = google-beta
  project  = var.project_id

  source {
    files {
      name    = "storage.rules"
      content = file(var.storage_rules)
    }
  }
}

resource "google_firebaserules_release" "storage" {
  provider     = google-beta
  project      = var.project_id
  name         = "firebase.storage/${var.project_id}.firebasestorage.app"
  ruleset_name = google_firebaserules_ruleset.storage.name

  depends_on = [google_firebaserules_ruleset.storage]
}
