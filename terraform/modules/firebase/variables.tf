variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-south1"
}

variable "firestore_rules" {
  description = "Path to Firestore rules file"
  type        = string
}

variable "storage_rules" {
  description = "Path to Storage rules file"
  type        = string
}

variable "firestore_indexes" {
  description = "List of Firestore composite indexes"
  type = list(object({
    collection  = string
    query_scope = optional(string, "COLLECTION")
    fields = list(object({
      field_path = string
      order      = optional(string)
      array_config = optional(string)
    }))
  }))
  default = []
}
