# Get existing VPC networks
data "google_compute_network" "primary_vpc" {
  name = "primary-vpc"
}

# ==========================================
# PRIVATE IP FOR CLOUD SQL
# ==========================================

resource "google_compute_global_address" "primary_sql_ip" {
  name          = "primary-sql-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = data.google_compute_network.primary_vpc.id
}

resource "google_service_networking_connection" "primary_vpc_connection" {
  network                 = data.google_compute_network.primary_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.primary_sql_ip.name]
}

# ==========================================
# PRIMARY DATABASE
# ==========================================

resource "google_sql_database_instance" "primary" {
  name             = "primary-mysql-${var.environment}"
  database_version = "MYSQL_8_0"
  region           = var.primary_region

  settings {
    # Free tier: db-f1-micro, Paid tier: db-n1-standard-2
    tier = var.use_high_availability ? "db-n1-standard-2" : "db-f1-micro"
    
    # Free tier: ZONAL, Paid tier: REGIONAL
    availability_type = var.use_high_availability ? "REGIONAL" : "ZONAL"
    
    disk_size       = var.use_high_availability ? 100 : 10
    disk_type       = "PD_SSD"
    disk_autoresize = true
    
    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      binary_log_enabled             = true
      point_in_time_recovery_enabled = var.use_high_availability
      transaction_log_retention_days = var.use_high_availability ? 7 : 1
      
      backup_retention_settings {
        retained_backups = var.use_high_availability ? 30 : 7
        retention_unit   = "COUNT"
      }
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = data.google_compute_network.primary_vpc.id
      require_ssl     = var.use_high_availability
    }

    maintenance_window {
      day          = 7
      hour         = 3
      update_track = "stable"
    }

    database_flags {
      name  = "max_connections"
      value = var.use_high_availability ? "1000" : "100"
    }
  }

  deletion_protection = var.use_high_availability

  depends_on = [google_service_networking_connection.primary_vpc_connection]
}

# ==========================================
# SECONDARY REPLICA (CROSS-REGION DR)
# Note: Must use same VPC as primary
# ==========================================

resource "google_sql_database_instance" "secondary_replica" {
  name                 = "secondary-mysql-replica-${var.environment}"
  database_version     = "MYSQL_8_0"
  region               = var.secondary_region
  master_instance_name = google_sql_database_instance.primary.name

  settings {
    tier              = var.use_high_availability ? "db-n1-standard-2" : "db-f1-micro"
    availability_type = var.use_high_availability ? "REGIONAL" : "ZONAL"
    disk_size         = var.use_high_availability ? 100 : 10
    disk_type         = "PD_SSD"

    ip_configuration {
      ipv4_enabled    = false
      private_network = data.google_compute_network.primary_vpc.id  # Same VPC as primary
      require_ssl     = var.use_high_availability
    }

    database_flags {
      name  = "max_connections"
      value = var.use_high_availability ? "1000" : "100"
    }
  }

  deletion_protection = var.use_high_availability

  depends_on = [
    google_service_networking_connection.primary_vpc_connection,
    google_sql_database_instance.primary
  ]
}

# ==========================================
# CREATE DATABASE AND USER
# ==========================================

resource "google_sql_database" "app_database" {
  name     = "appdb"
  instance = google_sql_database_instance.primary.name
}

resource "google_sql_user" "app_user" {
  name     = "appuser"
  instance = google_sql_database_instance.primary.name
  password = var.db_password
}