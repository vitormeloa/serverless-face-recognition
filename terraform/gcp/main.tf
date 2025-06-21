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
  type        = "FIRESTORE_NATIVE"
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
  project = var.gcp_project_id
}

# resource "google_project_iam_member" "register_vision" {
#   role   = "roles/vision.user"
#   member = "serviceAccount:${google_service_account.register_sa.email}"
#   project = var.gcp_project_id
# }

resource "google_project_iam_member" "register_firestore" {
  role   = "roles/datastore.user"
  member = "serviceAccount:${google_service_account.register_sa.email}"
  project = var.gcp_project_id
}

resource "google_project_iam_member" "register_pubsub" {
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${google_service_account.register_sa.email}"
  project = var.gcp_project_id
}

resource "google_cloudfunctions_function_iam_member" "register_invoker" {
  project        = var.gcp_project_id
  region         = var.gcp_region
  cloud_function = google_cloudfunctions_function.register_face.name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers"
}

###############################
# IAM Bindings for Recognize SA
###############################

resource "google_project_iam_member" "recognize_storage" {
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.recognize_sa.email}"
  project = var.gcp_project_id
}

# resource "google_project_iam_member" "recognize_vision" {
#   role   = "roles/vision.user"
#   member = "serviceAccount:${google_service_account.recognize_sa.email}"
#   project = var.gcp_project_id
# }

resource "google_project_iam_member" "recognize_firestore" {
  role   = "roles/datastore.viewer"
  member = "serviceAccount:${google_service_account.recognize_sa.email}"
  project = var.gcp_project_id
}

resource "google_cloudfunctions_function_iam_member" "recognize_invoker" {
  project        = var.gcp_project_id
  region         = var.gcp_region
  cloud_function = google_cloudfunctions_function.recognize_face.name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers"
}

resource "google_project_iam_member" "recognize_storage_writer" {
  project = var.gcp_project_id
  role    = "roles/storage.objectCreator"   # ou "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.recognize_sa.email}"
}

###############################
# Package Cloud Functions
###############################

data "archive_file" "register_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../gcp_functions/register"
  output_path = "${path.module}/register_face_deployment.zip"
}

data "archive_file" "recognize_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../gcp_functions/recognize"
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
  provider = google-beta
  api_id = "face-recognition-api"
}

data "template_file" "openapi" {
  template = <<EOT
swagger: '2.0'
info:
  title: FaceRecognitionAPI
  version: 1.0.0

host: "${var.gcp_project_id}.cloudfunctions.net"
schemes:
  - https

paths:
  /register:
    post:
      operationId: registerFace
      x-google-backend:
        address: ${google_cloudfunctions_function.register_face.https_trigger_url}
      responses:
        '200':
          description: OK

  /recognize:
    post:
      operationId: recognizeFace
      x-google-backend:
        address: ${google_cloudfunctions_function.recognize_face.https_trigger_url}
      responses:
        '200':
          description: OK
EOT
}

resource "google_api_gateway_api_config" "face_config" {
  provider      = google-beta
  api           = google_api_gateway_api.face_api.api_id
  api_config_id = "v1"

  openapi_documents {
    document {
      path     = "openapi.yaml"
      contents = base64encode(data.template_file.openapi.rendered)
    }
  }

  depends_on = [
    google_cloudfunctions_function.register_face,
    google_cloudfunctions_function.recognize_face,
  ]
}

resource "google_api_gateway_gateway" "face_gateway" {
  provider    = google-beta
  project     = var.gcp_project_id
  gateway_id  = "face-recognition-gateway"
  api_config  = google_api_gateway_api_config.face_config.id
  region      = var.gcp_region
}