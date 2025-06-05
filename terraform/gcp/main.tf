###############################
# Google Cloud Storage bucket
###############################
resource "google_storage_bucket" "face_images" {
  name     = var.bucket_name
  location = var.gcp_region

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
    condition {
      age = 30
    }
  }
}

###############################
# Pub/Sub topic
###############################
resource "google_pubsub_topic" "face_registration" {
  name = var.pubsub_topic_name
}

###############################
# Firestore database
###############################
resource "google_firestore_database" "db" {
  name        = var.firestore_database
  location_id = var.gcp_region
  type        = "NATIVE"
}

###############################
# Service Accounts
###############################
resource "google_service_account" "register_sa" {
  account_id   = "register-face-func-sa"
  display_name = "Register Face Function SA"
}

resource "google_service_account" "recognize_sa" {
  account_id   = "recognize-face-func-sa"
  display_name = "Recognize Face Function SA"
}

###############################
# IAM Bindings for Register SA
###############################
resource "google_project_iam_member" "register_storage" {
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.register_sa.email}"
}
resource "google_project_iam_member" "register_vision" {
  role   = "roles/vision.user"
  member = "serviceAccount:${google_service_account.register_sa.email}"
}
resource "google_project_iam_member" "register_firestore" {
  role   = "roles/datastore.user"
  member = "serviceAccount:${google_service_account.register_sa.email}"
}
resource "google_project_iam_member" "register_pubsub" {
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${google_service_account.register_sa.email}"
}

###############################
# IAM Bindings for Recognize SA
###############################
resource "google_project_iam_member" "recognize_storage" {
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.recognize_sa.email}"
}
resource "google_project_iam_member" "recognize_vision" {
  role   = "roles/vision.user"
  member = "serviceAccount:${google_service_account.recognize_sa.email}"
}
resource "google_project_iam_member" "recognize_firestore" {
  role   = "roles/datastore.viewer"
  member = "serviceAccount:${google_service_account.recognize_sa.email}"
}

###############################
# Package Cloud Functions
###############################
data "archive_file" "register_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../gcp_functions"
  output_path = "${path.module}/register_face_deployment.zip"
}

data "archive_file" "recognize_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../gcp_functions"
  output_path = "${path.module}/recognize_face_deployment.zip"
}

resource "google_storage_bucket_object" "register_archive" {
  name   = "register_face_deployment.zip"
  bucket = google_storage_bucket.face_images.name
  source = data.archive_file.register_zip.output_path
}

resource "google_storage_bucket_object" "recognize_archive" {
  name   = "recognize_face_deployment.zip"
  bucket = google_storage_bucket.face_images.name
  source = data.archive_file.recognize_zip.output_path
}

###############################
# Cloud Functions
###############################
resource "google_cloudfunctions_function" "register_face" {
  name        = "registerFaceFunction"
  runtime     = var.gcp_function_runtime
  entry_point = "registerFace"
  timeout     = var.gcp_function_timeout
  available_memory_mb = 256
  service_account_email = google_service_account.register_sa.email
  source_archive_bucket = google_storage_bucket.face_images.name
  source_archive_object = google_storage_bucket_object.register_archive.name
  trigger_http = true
  ingress_settings = "ALLOW_ALL"
  environment_variables = {
    BUCKET_NAME   = google_storage_bucket.face_images.name
    PUBSUB_TOPIC  = google_pubsub_topic.face_registration.name
    FIRESTORE_DB  = google_firestore_database.db.name
    PROJECT_ID    = var.gcp_project_id
  }
}

resource "google_cloudfunctions_function" "recognize_face" {
  name        = "recognizeFaceFunction"
  runtime     = var.gcp_function_runtime
  entry_point = "recognizeFace"
  timeout     = var.gcp_function_timeout
  available_memory_mb = 256
  service_account_email = google_service_account.recognize_sa.email
  source_archive_bucket = google_storage_bucket.face_images.name
  source_archive_object = google_storage_bucket_object.recognize_archive.name
  trigger_http = true
  ingress_settings = "ALLOW_ALL"
  environment_variables = {
    BUCKET_NAME  = google_storage_bucket.face_images.name
    FIRESTORE_DB = google_firestore_database.db.name
    PROJECT_ID   = var.gcp_project_id
  }
}

###############################
# API Gateway
###############################
resource "google_api_gateway_api" "face_api" {
  api_id = "face-recognition-api"
}

data "template_file" "openapi" {
  template = <<EOT
openapi: 2.0
info:
  title: FaceRecognitionAPI
  version: 1.0.0
paths:
  /register:
    post:
      x-google-backend:
        address: ${google_cloudfunctions_function.register_face.https_trigger_url}
      responses:
        '200':
          description: OK
  /recognize:
    post:
      x-google-backend:
        address: ${google_cloudfunctions_function.recognize_face.https_trigger_url}
      responses:
        '200':
          description: OK
EOT
}

resource "google_api_gateway_api_config" "face_config" {
  api       = google_api_gateway_api.face_api.id
  config_id = "v1"
  openapi_documents {
    document {
      path     = "openapi.yaml"
      contents = data.template_file.openapi.rendered
    }
  }
  depends_on = [
    google_cloudfunctions_function.register_face,
    google_cloudfunctions_function.recognize_face
  ]
}

resource "google_api_gateway_gateway" "face_gateway" {
  api        = google_api_gateway_api.face_api.id
  api_config = google_api_gateway_api_config.face_config.id
  location   = var.gcp_region
}
