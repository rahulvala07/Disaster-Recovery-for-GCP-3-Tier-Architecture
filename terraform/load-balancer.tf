# ==========================================
# GLOBAL LOAD BALANCER
# ==========================================

resource "google_compute_global_address" "default" {
  name = "global-lb-ip"
}

# Backend service - Primary region
resource "google_compute_backend_service" "primary_web_backend" {
  name                  = "primary-web-backend"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  health_checks         = [google_compute_health_check.web_health_check.id]
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group           = google_compute_region_instance_group_manager.primary_web.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  # Attach Cloud Armor if enabled
  security_policy = google_compute_security_policy.cloud_armor.id

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# Backend service - Secondary region (failover)
resource "google_compute_backend_service" "secondary_web_backend" {
  name                  = "secondary-web-backend"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  health_checks         = [google_compute_health_check.web_health_check.id]
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group           = google_compute_region_instance_group_manager.secondary_web.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  security_policy = google_compute_security_policy.cloud_armor.id

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# URL Map with failover
resource "google_compute_url_map" "default" {
  name            = "web-url-map"
  default_service = google_compute_backend_service.primary_web_backend.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.primary_web_backend.id

    route_rules {
      priority = 1
      match_rules {
        prefix_match = "/"
      }
      route_action {
        weighted_backend_services {
          backend_service = google_compute_backend_service.primary_web_backend.id
          weight          = 100
        }
        weighted_backend_services {
          backend_service = google_compute_backend_service.secondary_web_backend.id
          weight          = 0  # Failover only
        }
      }
    }
  }
}

# Target HTTP proxy
resource "google_compute_target_http_proxy" "default" {
  name    = "http-proxy"
  url_map = google_compute_url_map.default.id
}

# HTTP Forwarding rule
resource "google_compute_global_forwarding_rule" "http" {
  name                  = "http-forwarding-rule"
  target                = google_compute_target_http_proxy.default.id
  port_range            = "80"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.default.address
}