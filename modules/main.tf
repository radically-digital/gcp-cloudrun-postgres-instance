variable "project" {
  type        = string
  description = "gcp project name"
}

variable "image_name" {
  type = string
}

variable "domain" {
  type = string
}

variable "team" {
  type = string
}

variable "service_api_list" {
  type        = list(string)
  description = "List of required service API's eg: [\"cloudkms\"] from CLOUDSDK_CORE_PROJECT=<project> gcloud services list --available"
}

variable "service_name" {
  description = "Name must be unique within a namespace"
  type        = string
}

variable "location" {
  description = "The location of the cloud run instance"
  type        = string
}

variable "container_env" {
  description = "Map of environment variables that will be passed to the container"
  type        = map(string)
  default     = null
}

variable "container_port" {
  description = "TCP port to open in the container"
  type        = number
  default     = 8080
}

variable "container_resources_limits_cpus" {
  type        = number
  default     = 1
  description = "CPUs measured in 1000 cpu units to allocate to service instances. Have a look at https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#meaning-of-cpu for details."
}

variable "container_resources_limits_memory" {
  type        = number
  default     = 512
  description = "Memory in MiB (2^26 bytes) to allocate to service instances. Have a look at https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#meaning-of-memory for details."
}

variable "service_account_email" {
  description = "Email address of the IAM service account associated with the revision of the service. The service account represents the identity of the running revision, and determines what permissions the revision has. If not provided the revision will use the project's default service account (PROJECT_NUMBER-compute@developer.gserviceaccount.com)."
  type        = string
  default     = null
}

locals {
  container_env = merge(var.container_env, {
    DB_HOST = "/cloudsql/${google_sql_database_instance.default.connection_name}" # google_sql_database_instance.default.public_ip_address
    DB_PORT = 5432
    DB_USER = google_sql_user.db_user.name
    DB_PASS = random_password.db_password.result
    DB_NAME = google_sql_database.default.name
    DB_TYPE = "postgres"
  })
}

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location = google_cloud_run_service.default.location
  project  = google_cloud_run_service.default.project
  service  = google_cloud_run_service.default.name

  policy_data = data.google_iam_policy.noauth.policy_data
}

resource "random_password" "db_password" {
  length  = 10
  special = false
}


resource "google_service_account" "default" {
  account_id   = "${var.service_name}-service-account"
  display_name = "Service account for ${var.service_name}"
}

resource "google_artifact_registry_repository" "default" {
  provider = google-beta

  location      = var.location
  repository_id = var.service_name
  description   = "${var.service_name} docker repository"
  format        = "DOCKER"
}

output "_info-google_artifact_registry_repository" {
  description = "info output"
  value       = <<EOF
###
# To Setup locally or for docker tagging

# % gcloud auth configure-docker ${var.location}-docker.pkg.dev
# % gcloud auth application-default print-access-token | docker login -u oauth2accesstoken --password-stdin ${var.location}-docker.pkg.dev
# % docker tag <local_image> ${local.repository_address}/<image_name>:<version>
###
EOF
}

locals {
  repository_address = "${var.location}-docker.pkg.dev/${var.project}/${var.service_name}/${var.image_name}"
}

resource "google_project_iam_binding" "default" {
  role    = "roles/cloudsql.client"
  project = var.project
  members = [
    "serviceAccount:${google_service_account.default.email}"
  ]
}

resource "google_cloud_run_service" "default" {
  name     = "${var.service_name}-service"
  location = var.location

  template {
    spec {
      service_account_name = google_service_account.default.email

      containers {
        image = local.repository_address

        dynamic "env" {
          for_each = local.container_env != null ? local.container_env : {}
          content {
            name  = env.key
            value = env.value
          }
        }

        ports {
          container_port = var.container_port
        }

        resources {
          limits = {
            cpu    = "${var.container_resources_limits_cpus * 1000}m"
            memory = "${var.container_resources_limits_memory}Mi"
          }
        }
      }
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale"      = "2"
        "autoscaling.knative.dev/minScale"      = "1"
        "run.googleapis.com/cloudsql-instances" = google_sql_database_instance.default.connection_name
        "run.googleapis.com/client-name"        = "terraform"
        "run.googleapis.com/cpu-throttling"     = "false" # always on https://cloud.google.com/run/docs/configuring/cpu-allocation
      }
    }
  }

  autogenerate_revision_name = true

  depends_on = [google_artifact_registry_repository.default]
}

resource "random_id" "db_name_suffix" {
  byte_length = 4
}

resource "google_sql_user" "db_user" {
  name     = "${var.service_name}-user"
  instance = google_sql_database_instance.default.name
  password = random_password.db_password.result
}

resource "google_sql_database_instance" "default" {
  region           = var.location
  name             = "${var.service_name}-sql-${random_id.db_name_suffix.hex}"
  database_version = "POSTGRES_13"
  settings {
    tier            = "db-f1-micro"
    disk_autoresize = true

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      location                       = "eu"
      start_time                     = "01:00"
    }

    maintenance_window {
      day  = 3
      hour = 23
    }

    insights_config {
      query_insights_enabled = true
      query_string_length    = 1024
    }
  }

  deletion_protection = "true"
}

resource "google_sql_database" "default" {
  name     = var.service_name
  instance = google_sql_database_instance.default.id

  collation = "en_US.UTF8"
}

resource "google_project_service" "default" {
  for_each = toset(var.service_api_list)

  service = "${each.key}.googleapis.com"

  disable_dependent_services = true
}

resource "google_cloud_run_domain_mapping" "default" {
  location = var.location
  name     = var.domain

  metadata {
    namespace = var.project
  }

  spec {
    route_name = google_cloud_run_service.default.name
  }
}

resource "google_iap_brand" "default" {
  support_email     = var.team
  application_title = var.service_name

  lifecycle {
    ignore_changes = [
      org_internal_only
    ]
  }
}

output "_info-google_iap_client" {
  description = "info output"
  value       = <<EOF
###
#
# Only internal org clients can be created via declarative tools.
# External clients must be manually created via the GCP console.
# This restriction is due to the existing APIs and not lack of support in this tool.
#
# https://console.cloud.google.com/apis/credentials/oauthclient
#
# Change google_iap_brand to external via:
# https://console.cloud.google.com/apis/credentials/consent
#
###
EOF
}
