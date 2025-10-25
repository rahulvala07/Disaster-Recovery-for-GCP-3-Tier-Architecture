# Get existing subnets
data "google_compute_subnetwork" "primary_web" {
  name   = "primary-web-subnet"
  region = var.primary_region
}

data "google_compute_subnetwork" "primary_app" {
  name   = "primary-app-subnet"
  region = var.primary_region
}

data "google_compute_subnetwork" "secondary_web" {
  name   = "secondary-web-subnet"
  region = var.secondary_region
}

data "google_compute_subnetwork" "secondary_app" {
  name   = "secondary-app-subnet"
  region = var.secondary_region
}

# ==========================================
# HEALTH CHECKS
# ==========================================

resource "google_compute_health_check" "web_health_check" {
  name                = "web-health-check"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 80
    request_path = "/health"
  }
}

resource "google_compute_health_check" "app_health_check" {
  name                = "app-health-check"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 8080
    request_path = "/health"
  }
}

# ==========================================
# INSTANCE TEMPLATES - PRIMARY REGION
# ==========================================

resource "google_compute_instance_template" "primary_web" {
  name_prefix  = "primary-web-"
  machine_type = "e2-medium"
  region       = var.primary_region

  tags = ["web-server", "allow-ssh", "allow-health-check"]

  disk {
    source_image = "debian-cloud/debian-11"
    auto_delete  = true
    boot         = true
    disk_size_gb = 20
  }

  network_interface {
    subnetwork = data.google_compute_subnetwork.primary_web.id
  }

  metadata = {
    startup-script = file("${path.module}/scripts/web-startup.sh")
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_template" "primary_app" {
  name_prefix  = "primary-app-"
  machine_type = "e2-standard-2"
  region       = var.primary_region

  tags = ["app-server", "allow-ssh", "allow-health-check"]

  disk {
    source_image = "debian-cloud/debian-11"
    auto_delete  = true
    boot         = true
    disk_size_gb = 30
  }

  network_interface {
    subnetwork = data.google_compute_subnetwork.primary_app.id
  }

  metadata = {
    startup-script = file("${path.module}/scripts/app-startup.sh")
    db-host        = google_sql_database_instance.primary.private_ip_address
    db-name        = google_sql_database.app_database.name
    db-user        = google_sql_user.app_user.name
    db-pass        = var.db_password
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ==========================================
# INSTANCE TEMPLATES - SECONDARY REGION
# ==========================================

resource "google_compute_instance_template" "secondary_web" {
  name_prefix  = "secondary-web-"
  machine_type = "e2-medium"
  region       = var.secondary_region

  tags = ["web-server", "allow-ssh", "allow-health-check"]

  disk {
    source_image = "debian-cloud/debian-11"
    auto_delete  = true
    boot         = true
    disk_size_gb = 20
  }

  network_interface {
    subnetwork = data.google_compute_subnetwork.secondary_web.id
  }

  metadata = {
    startup-script = file("${path.module}/scripts/web-startup.sh")
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_template" "secondary_app" {
  name_prefix  = "secondary-app-"
  machine_type = "e2-standard-2"
  region       = var.secondary_region

  tags = ["app-server", "allow-ssh", "allow-health-check"]

  disk {
    source_image = "debian-cloud/debian-11"
    auto_delete  = true
    boot         = true
    disk_size_gb = 30
  }

  network_interface {
    subnetwork = data.google_compute_subnetwork.secondary_app.id
  }

  metadata = {
    startup-script = file("${path.module}/scripts/app-startup.sh")
    db-host        = google_sql_database_instance.secondary_replica.private_ip_address
    db-name        = google_sql_database.app_database.name
    db-user        = google_sql_user.app_user.name
    db-pass        = var.db_password
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ==========================================
# MANAGED INSTANCE GROUPS - PRIMARY
# ==========================================

resource "google_compute_region_instance_group_manager" "primary_web" {
  name   = "primary-web-mig"
  region = var.primary_region

  base_instance_name = "primary-web"
  target_size        = 2

  version {
    instance_template = google_compute_instance_template.primary_web.id
  }

  named_port {
    name = "http"
    port = 80
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.web_health_check.id
    initial_delay_sec = 300
  }
}

resource "google_compute_region_instance_group_manager" "primary_app" {
  name   = "primary-app-mig"
  region = var.primary_region

  base_instance_name = "primary-app"
  target_size        = 2

  version {
    instance_template = google_compute_instance_template.primary_app.id
  }

  named_port {
    name = "http"
    port = 8080
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.app_health_check.id
    initial_delay_sec = 300
  }
}

# ==========================================
# MANAGED INSTANCE GROUPS - SECONDARY (WARM STANDBY)
# ==========================================

resource "google_compute_region_instance_group_manager" "secondary_web" {
  name   = "secondary-web-mig"
  region = var.secondary_region

  base_instance_name = "secondary-web"
  target_size        = 1  # Warm standby

  version {
    instance_template = google_compute_instance_template.secondary_web.id
  }

  named_port {
    name = "http"
    port = 80
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.web_health_check.id
    initial_delay_sec = 300
  }
}

resource "google_compute_region_instance_group_manager" "secondary_app" {
  name   = "secondary-app-mig"
  region = var.secondary_region

  base_instance_name = "secondary-app"
  target_size        = 1  # Warm standby

  version {
    instance_template = google_compute_instance_template.secondary_app.id
  }

  named_port {
    name = "http"
    port = 8080
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.app_health_check.id
    initial_delay_sec = 300
  }
}

# ==========================================
# AUTOSCALING
# ==========================================

resource "google_compute_region_autoscaler" "primary_web" {
  name   = "primary-web-autoscaler"
  region = var.primary_region
  target = google_compute_region_instance_group_manager.primary_web.id

  autoscaling_policy {
    max_replicas    = 10
    min_replicas    = 2
    cooldown_period = 60

    cpu_utilization {
      target = 0.7
    }
  }
}

resource "google_compute_region_autoscaler" "primary_app" {
  name   = "primary-app-autoscaler"
  region = var.primary_region
  target = google_compute_region_instance_group_manager.primary_app.id

  autoscaling_policy {
    max_replicas    = 8
    min_replicas    = 2
    cooldown_period = 60

    cpu_utilization {
      target = 0.7
    }
  }
}

resource "google_compute_region_autoscaler" "secondary_web" {
  name   = "secondary-web-autoscaler"
  region = var.secondary_region
  target = google_compute_region_instance_group_manager.secondary_web.id

  autoscaling_policy {
    max_replicas    = 6
    min_replicas    = 1
    cooldown_period = 60

    cpu_utilization {
      target = 0.7
    }
  }
}

resource "google_compute_region_autoscaler" "secondary_app" {
  name   = "secondary-app-autoscaler"
  region = var.secondary_region
  target = google_compute_region_instance_group_manager.secondary_app.id

  autoscaling_policy {
    max_replicas    = 4
    min_replicas    = 1
    cooldown_period = 60

    cpu_utilization {
      target = 0.7
    }
  }
}