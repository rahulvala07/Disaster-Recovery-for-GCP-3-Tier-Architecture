output "load_balancer_ip" {
  description = "Load Balancer IP Address"
  value       = google_compute_global_address.default.address
}

output "primary_database_ip" {
  description = "Primary Database Private IP"
  value       = google_sql_database_instance.primary.private_ip_address
}

output "secondary_database_ip" {
  description = "Secondary Database Private IP"
  value       = google_sql_database_instance.secondary_replica.private_ip_address
}

output "primary_db_connection" {
  description = "Primary Database Connection Name"
  value       = google_sql_database_instance.primary.connection_name
}

output "secondary_db_connection" {
  description = "Secondary Database Connection Name"
  value       = google_sql_database_instance.secondary_replica.connection_name
}

output "primary_web_instances" {
  description = "Primary Web Instance Group"
  value       = google_compute_region_instance_group_manager.primary_web.instance_group
}

output "secondary_web_instances" {
  description = "Secondary Web Instance Group"
  value       = google_compute_region_instance_group_manager.secondary_web.instance_group
}

output "cloud_armor_enabled" {
  description = "Cloud Armor Status"
  value       = var.enable_cloud_armor ? "Enabled" : "Disabled (Free Tier)"
}

output "database_tier" {
  description = "Database Tier"
  value       = var.use_high_availability ? "High Availability" : "Basic (Free Tier)"
}