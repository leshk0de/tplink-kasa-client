# Configure the Google Cloud provider
provider "google" {
  project = var.project_id
  region  = var.region
}


# Zip up the source code for kasa-h300
data "archive_file" "function_src_h300_zip" {
    type        = "zip"
    source_dir  = "${path.module}/../src"
    output_path = "/tmp/${var.function_h300}.zip"
    excludes    = var.python_excludes
}

#copy function_src_h300_zip to souce bucket where it will be deployed from
resource "google_storage_bucket_object" "function_src_h300_zip" {
    name   = "${var.function_h300}-${data.archive_file.function_src_h300_zip.output_md5}.zip"
    bucket = data.google_storage_bucket.functions_src.name
    source = data.archive_file.function_src_h300_zip.output_path
}

# No longer used
# data "archive_file" "function_src_smart_plug_zip" {
#     type        = "zip"
#     source_dir  = "${path.module}/../smartPlug/src"
#     output_path = "/tmp/${var.function_smartplug}.zip"
#     excludes    = var.python_excludes
# }

# No longer used
# #copy function_src_smart_plug_zip to souce bucket where it will be deployed from
# resource "google_storage_bucket_object" "function_src_smart_plug_zip" {
#     name   = "${var.function_smartplug}-${data.archive_file.function_src_smart_plug_zip.output_md5}.zip"
#     bucket = data.google_storage_bucket.functions_src.name
#     source = data.archive_file.function_src_smart_plug_zip.output_path
# }


resource "google_service_account" "function_sa" {
  account_id   = "sa-${var.function_base_name}"
  display_name = "Service account for ${var.function_base_name} app"
}

# Create a Cloud Function that triggers on the topic
resource "google_cloudfunctions_function" "kasa_hydrop_h300" {
  name        = var.function_h300
  description = "Cloud function that pulls metrics from kasa-h300 sensor"
  runtime     = "python39"
  entry_point = "pull_data"
  service_account_email = google_service_account.function_sa.email

  # Use the Pub/Sub trigger
  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = "projects/${var.project_id}/topics/every-5min"
  }

  environment_variables = {
    SECRET_ID = google_secret_manager_secret.function_secret.name
  }

  # Use the default function code
  source_archive_bucket = data.google_storage_bucket.functions_src.name
  source_archive_object = google_storage_bucket_object.function_src_h300_zip.name

  depends_on = [ google_service_account.function_sa  ]
}

# No longer used
# Create a Cloud Function that triggers on the topic
# resource "google_cloudfunctions_function" "kasa_hydrop_smart_plug" {
#   name        = var.function_smartplug
#   description = "Cloud function that pulls metrics from smart plug sensor"
#   runtime     = "python39"
#   entry_point = "pull_data"
#   service_account_email = google_service_account.function_sa.email

#   # Use the Pub/Sub trigger
#   event_trigger {
#     event_type = "google.pubsub.topic.publish"
#     resource   = "projects/${var.project_id}/topics/every-5min"
#   }

#   environment_variables = {
#     SECRET_ID = google_secret_manager_secret.function_secret.name
#   }

#   # Use the default function code
#   source_archive_bucket = data.google_storage_bucket.functions_src.name
#   source_archive_object = google_storage_bucket_object.function_src_smart_plug_zip.name

#   depends_on = [ google_service_account.function_sa  ]
# }


# Create a Cloud Storage bucket to store function output
resource "google_storage_bucket" "function_bucket" {
  name = "${var.function_base_name}-data"
  location = "us"
}

resource "google_storage_bucket_iam_binding" "binding" {
  bucket = google_storage_bucket.function_bucket.name
  role = "roles/storage.admin"
  members = [
    "serviceAccount:${google_service_account.function_sa.email}",
  ]

  depends_on = [ google_service_account.function_sa ]
}


resource "google_secret_manager_secret" "function_secret" {
  secret_id = "${var.function_base_name}-secrets"
  replication {
    auto {}
  }

}

resource "google_secret_manager_secret_iam_binding" "binding" {
  project = var.project_id
  secret_id = google_secret_manager_secret.function_secret.secret_id
  role = "roles/secretmanager.secretAccessor"
  members = [
    "serviceAccount:${google_service_account.function_sa.email}"
  ]
  depends_on = [ google_service_account.function_sa ]
}

# Misc list to files during deployment
variable "python_excludes" {
  description = "Files to exclude from python cloud function src directory"
  type        = list(string)
  default     = [
    ".venv",
    "README.md",
    "testing",
    "deploy.sh",
    ".env",
    "misc",
    "notes.txt",
    "__pycache__"
  ]
}

output "function-name" {
  value = google_cloudfunctions_function.kasa_hydrop_h300.name
}
output "function-trigger" {
  value = google_cloudfunctions_function.kasa_hydrop_h300.https_trigger_url
}
output "function-bucket" {
  value = google_storage_bucket.function_bucket.name
}