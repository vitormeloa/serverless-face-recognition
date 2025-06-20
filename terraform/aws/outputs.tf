output "register_endpoint" {
  description = "API Gateway register endpoint"
  value       = "${aws_api_gateway_stage.prod.invoke_url}/register"
}

output "recognize_endpoint" {
  description = "API Gateway recognize endpoint"
  value       = "${aws_api_gateway_stage.prod.invoke_url}/recognize"
}

output "bucket_name" {
  description = "S3 bucket storing images"
  value       = aws_s3_bucket.face_images.bucket
}