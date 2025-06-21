variable "gcp_project_id" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "bucket_name" {
  description = "GCS bucket name"
  type        = string
  default     = "face-images-gcp-comparison"
}

variable "firestore_database" {
  description = "Firestore database ID"
  type        = string
  default     = "(default)"
}

variable "pubsub_topic_name" {
  description = "Pub/Sub topic name"
  type        = string
  default     = "face-registration-topic"
}

variable "gcp_function_runtime" {
  description = "Cloud Function runtime"
  type        = string
  default     = "nodejs18"
}

variable "gcp_function_timeout" {
  description = "Function timeout"
  type        = number
  default     = "60"
}