variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "dr-mumbai-delhi-prod"
}

variable "primary_region" {
  description = "Primary region (Mumbai)"
  type        = string
  default     = "asia-south1"
}

variable "secondary_region" {
  description = "Secondary region (Delhi)"
  type        = string
  default     = "asia-south2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "alert_email" {
  description = "Email for monitoring alerts"
  type        = string
}

variable "enable_cloud_armor" {
  description = "Enable Cloud Armor (requires paid tier)"
  type        = bool
  default     = false
}

variable "use_high_availability" {
  description = "Use regional HA for database (paid tier)"
  type        = bool
  default     = false
}