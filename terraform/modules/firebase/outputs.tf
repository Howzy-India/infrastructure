output "firestore_database_name" {
  description = "Firestore database name"
  value       = google_firestore_database.default.name
}

output "firebase_project_id" {
  description = "Firebase project ID"
  value       = google_firebase_project.default.project
}
