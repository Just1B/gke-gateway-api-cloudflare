terraform {
    required_providers {
      google = {
        source  = "hashicorp/google"
        version = "~>6.2"
      }

      cloudflare = {
        source  = "cloudflare/cloudflare"
        version = "~>4.4"
      }
    }
  }

  provider "google" {
    project = var.master_project_name
  }

  provider "cloudflare" {
    api_token = var.cloudflare_api_key
  }

  // ################################################################
  //  CLOUDFLARE ORIGIN SERVER CERTIFICATE
  // ################################################################

  resource "tls_private_key" "default" {
    algorithm = "RSA"
  }

  resource "tls_cert_request" "default" {
    private_key_pem = tls_private_key.default.private_key_pem

    subject {
      organization = "Demo ORG"
      common_name  = var.domain
    }
  }

  resource "cloudflare_origin_ca_certificate" "demo_origin_cert" {
    csr = tls_cert_request.default.cert_request_pem
    hostnames = [
      var.domain,
      "*.${var.domain}",
    ]
    request_type       = "origin-rsa"
    requested_validity = 5475 # 15 years
  }

  // ################################################################
  //  GCP CERT MANAGER BINDING
  // ################################################################

  # List certificates : gcloud certificate-manager certificates list
  resource "google_certificate_manager_certificate" "demo_cert" {
    name = "demo-cert"

    self_managed {
      pem_certificate = cloudflare_origin_ca_certificate.demo_origin_cert.certificate
      pem_private_key = tls_private_key.default.private_key_pem
    }

    labels = {
      "terraform" : true,
    }
  }

  # List maps : gcloud certificate-manager maps list
  resource "google_certificate_manager_certificate_map" "cert_map" {
    name = "demo-cert-map"

    labels = {
      "terraform" : true,
    }
  }

  # List entries : gcloud beta certificate-manager maps entries list --map=demo-cert-map
  resource "google_certificate_manager_certificate_map_entry" "certificate_map_entry" {
    name     = "demo-cert-map-entry"
    map      = google_certificate_manager_certificate_map.cert_map.name
    certificates = [google_certificate_manager_certificate.demo_cert.id]
    hostname = var.domain

    labels = {
      "terraform" : true,
    }
  }

  resource "google_certificate_manager_certificate_map_entry" "certificate_map_entry_wildcard" {
    name     = "demo-wildcard-cert-map-entry"
    map      = google_certificate_manager_certificate_map.cert_map.name
    certificates = [google_certificate_manager_certificate.demo_cert.id]
    hostname = "*.${var.domain}"

    labels = {
      "terraform" : true,
    }
  }