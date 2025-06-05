output "gcp_register_function_url" {
  description = "Direct URL for registerFaceFunction"
  value       = google_cloudfunctions_function.register_face.https_trigger_url
}

output "gcp_recognize_function_url" {
  description = "Direct URL for recognizeFaceFunction"
  value       = google_cloudfunctions_function.recognize_face.https_trigger_url
}

output "gcp_api_gateway_url" {
  description = "Base URL for API Gateway"
  value       = google_api_gateway_gateway.face_gateway.default_hostname
}
