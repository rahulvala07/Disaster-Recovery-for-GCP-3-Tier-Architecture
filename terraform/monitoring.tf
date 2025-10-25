# ==========================================
# MONITORING & ALERTING
# ==========================================

resource "google_monitoring_notification_channel" "email" {
  display_name = "Email Notification"
  type         = "email"
  
  labels = {
    email_address = var.alert_email
  }
}

# Alert: Database down
resource "google_monitoring_alert_policy" "database_down" {
  display_name = "Database Instance Down"
  combiner     = "OR"

  conditions {
    display_name = "Database unavailable"
    
    condition_threshold {
      filter          = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/up\""
      duration        = "120s"
      comparison      = "COMPARISON_LT"
      threshold_value = 1
      
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]
  
  alert_strategy {
    auto_close = "1800s"
  }
}

# Alert: High CPU
resource "google_monitoring_alert_policy" "high_cpu" {
  display_name = "High CPU Usage"
  combiner     = "OR"

  conditions {
    display_name = "CPU > 80%"
    
    condition_threshold {
      filter          = "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/cpu/utilization\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]
}

# Uptime check
resource "google_monitoring_uptime_check_config" "http_check" {
  display_name = "Load Balancer Uptime"
  timeout      = "10s"
  period       = "300s"

  http_check {
    path    = "/"
    port    = "80"
    use_ssl = false
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = google_compute_global_address.default.address
    }
  }

  content_matchers {
    content = "GCP"
    matcher = "CONTAINS_STRING"
  }
}