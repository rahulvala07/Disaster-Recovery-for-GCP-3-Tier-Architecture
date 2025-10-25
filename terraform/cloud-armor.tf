# ==========================================
# CLOUD ARMOR (WAF) - PAID TIER ONLY
# ==========================================

resource "google_compute_security_policy" "cloud_armor" {
  count = "cloud-armor-policy"
  
  name = "cloud-armor-waf-policy"

  # Rule 1: Block SQL Injection
  rule {
    action   = "deny(403)"
    priority = 1000
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-v33-stable')"
      }
    }
    description = "Block SQL injection attacks"
  }

  # Rule 2: Block XSS
  rule {
    action   = "deny(403)"
    priority = 2000
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-v33-stable')"
      }
    }
    description = "Block XSS attacks"
  }

  # Rule 3: Block LFI
  rule {
    action   = "deny(403)"
    priority = 3000
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('lfi-v33-stable')"
      }
    }
    description = "Block LFI attacks"
  }

  # Rule 4: Block RCE
  rule {
    action   = "deny(403)"
    priority = 4000
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rce-v33-stable')"
      }
    }
    description = "Block RCE attacks"
  }

  # Rule 5: Rate limiting
  rule {
    action   = "rate_based_ban"
    priority = 5000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
      
      ban_duration_sec = 600
    }
    description = "Rate limit: 100 req/min per IP"
  }

  # Rule 6: Geographic blocking (optional)
  rule {
    action   = "deny(403)"
    priority = 6000
    match {
      expr {
        expression = "origin.region_code == 'XX' # You can Use Region Of Your Choice
      }
    }
    description = "Block specific countries"
  }

  # Rule 7: Allow your IP (whitelist) - CHANGE THIS!
  rule {
    action   = "allow"
    priority = 100
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["YOUR_IP_ADDRESS/32"]  # Replace with your IP
      }
    }
    description = "Allow trusted IPs"
  }
  
  # Default rule: Allow
  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow"
  }

  # Adaptive protection
  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable = true
    }
  }
}