variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "nodejs14.x"
}

variable "face_collection_id" {
  description = "Rekognition collection ID"
  type        = string
  default     = "face-collection"
}

variable "dynamo_table_name" {
  description = "DynamoDB table name"
  type        = string
  default     = "FaceMetadataTable"
}

variable "sns_topic_name" {
  description = "SNS topic name"
  type        = string
  default     = "FaceRegistrationTopic"
}

variable "bucket_name" {
  description = "S3 bucket name"
  type        = string
  default     = "face-images-bucket"
}

variable "project_tags" {
  description = "Common resource tags"
  type        = map(string)
  default = {
    Project     = "FaceRecognitionProject"
    Environment = "dev"
  }
}
