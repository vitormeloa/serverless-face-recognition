terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2"
    }
  }
}

provider "aws" {
  region = var.region
}

#############################
# S3 bucket for storing images
#############################
resource "aws_s3_bucket" "face_images" {
  bucket = var.bucket_name
  versioning {
    enabled = true
  }
  tags = var.project_tags
}

#############################
# DynamoDB table for metadata
#############################
resource "aws_dynamodb_table" "face_metadata" {
  name         = var.dynamo_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "faceId"

  attribute {
    name = "faceId"
    type = "S"
  }

  global_secondary_index {
    name            = "userId-index"
    hash_key        = "userId"
    projection_type = "ALL"
  }

  attribute {
    name = "userId"
    type = "S"
  }

  tags = var.project_tags
}

#################################
# Rekognition collection
#################################
resource "aws_rekognition_collection" "faces" {
  collection_id = var.face_collection_id
  tags          = var.project_tags
}

#################################
# SNS topic
#################################
resource "aws_sns_topic" "face_registration" {
  name = var.sns_topic_name
  tags = var.project_tags
}

#################################
# IAM roles and policies
#################################
# Role for RegisterFace Lambda
resource "aws_iam_role" "register_face_role" {
  name               = "lambda_register_face_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = var.project_tags
}

resource "aws_iam_role_policy" "register_face_policy" {
  name   = "register_face_policy"
  role   = aws_iam_role.register_face_role.id
  policy = data.aws_iam_policy_document.register_face_policy.json
}

# Role for RecognizeFace Lambda
resource "aws_iam_role" "recognize_face_role" {
  name               = "lambda_recognize_face_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = var.project_tags
}

resource "aws_iam_role_policy" "recognize_face_policy" {
  name   = "recognize_face_policy"
  role   = aws_iam_role.recognize_face_role.id
  policy = data.aws_iam_policy_document.recognize_face_policy.json
}

#############################
# IAM policies documents
#############################
# Lambda trust policy

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "register_face_policy" {
  statement {
    actions = ["s3:PutObject", "s3:GetObject"]
    resources = ["${aws_s3_bucket.face_images.arn}/*"]
  }
  statement {
    actions   = ["rekognition:IndexFaces"]
    resources = [aws_rekognition_collection.faces.arn]
  }
  statement {
    actions   = ["dynamodb:PutItem", "dynamodb:GetItem"]
    resources = [aws_dynamodb_table.face_metadata.arn]
  }
  statement {
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.face_registration.arn]
  }
  statement {
    actions = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

data "aws_iam_policy_document" "recognize_face_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.face_images.arn}/*"]
  }
  statement {
    actions   = ["rekognition:SearchFacesByImage"]
    resources = [aws_rekognition_collection.faces.arn]
  }
  statement {
    actions   = ["dynamodb:GetItem"]
    resources = [aws_dynamodb_table.face_metadata.arn]
  }
  statement {
    actions = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

#################################
# Lambda functions packaging
#################################

data "archive_file" "register_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_register"
  output_path = "${path.module}/lambda_register.zip"
}

data "archive_file" "recognize_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_recognize"
  output_path = "${path.module}/lambda_recognize.zip"
}

resource "aws_lambda_function" "register_face" {
  function_name = "RegisterFaceFunction"
  role          = aws_iam_role.register_face_role.arn
  handler       = "index.handler"
  runtime       = var.lambda_runtime
  filename      = data.archive_file.register_zip.output_path
  source_code_hash = data.archive_file.register_zip.output_base64sha256

  environment {
    variables = {
      FACE_COLLECTION_ID = var.face_collection_id
      DYNAMO_TABLE_NAME  = aws_dynamodb_table.face_metadata.name
      SNS_TOPIC_ARN      = aws_sns_topic.face_registration.arn
      BUCKET_NAME        = aws_s3_bucket.face_images.bucket
    }
  }
  tags = var.project_tags
}

resource "aws_lambda_function" "recognize_face" {
  function_name = "RecognizeFaceFunction"
  role          = aws_iam_role.recognize_face_role.arn
  handler       = "index.handler"
  runtime       = var.lambda_runtime
  filename      = data.archive_file.recognize_zip.output_path
  source_code_hash = data.archive_file.recognize_zip.output_base64sha256

  environment {
    variables = {
      FACE_COLLECTION_ID = var.face_collection_id
      DYNAMO_TABLE_NAME  = aws_dynamodb_table.face_metadata.name
      BUCKET_NAME        = aws_s3_bucket.face_images.bucket
    }
  }
  tags = var.project_tags
}

#################################
# API Gateway
#################################
resource "aws_api_gateway_rest_api" "face_api" {
  name = "FaceRecognitionAPI"
  tags = var.project_tags
}

resource "aws_api_gateway_resource" "register" {
  rest_api_id = aws_api_gateway_rest_api.face_api.id
  parent_id   = aws_api_gateway_rest_api.face_api.root_resource_id
  path_part   = "register"
}

resource "aws_api_gateway_resource" "recognize" {
  rest_api_id = aws_api_gateway_rest_api.face_api.id
  parent_id   = aws_api_gateway_rest_api.face_api.root_resource_id
  path_part   = "recognize"
}

resource "aws_api_gateway_method" "register_post" {
  rest_api_id   = aws_api_gateway_rest_api.face_api.id
  resource_id   = aws_api_gateway_resource.register.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "recognize_post" {
  rest_api_id   = aws_api_gateway_rest_api.face_api.id
  resource_id   = aws_api_gateway_resource.recognize.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "register_integration" {
  rest_api_id = aws_api_gateway_rest_api.face_api.id
  resource_id = aws_api_gateway_resource.register.id
  http_method = aws_api_gateway_method.register_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.register_face.invoke_arn
}

resource "aws_api_gateway_integration" "recognize_integration" {
  rest_api_id = aws_api_gateway_rest_api.face_api.id
  resource_id = aws_api_gateway_resource.recognize.id
  http_method = aws_api_gateway_method.recognize_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.recognize_face.invoke_arn
}

resource "aws_lambda_permission" "allow_apigw_register" {
  statement_id  = "AllowAPIGatewayInvokeRegister"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.register_face.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.face_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_apigw_recognize" {
  statement_id  = "AllowAPIGatewayInvokeRecognize"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.recognize_face.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.face_api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "prod" {
  depends_on = [
    aws_api_gateway_integration.register_integration,
    aws_api_gateway_integration.recognize_integration
  ]
  rest_api_id = aws_api_gateway_rest_api.face_api.id
  stage_name  = "prod"
}

resource "aws_api_gateway_stage" "prod" {
  rest_api_id = aws_api_gateway_rest_api.face_api.id
  deployment_id = aws_api_gateway_deployment.prod.id
  stage_name = "prod"
  tags       = var.project_tags
}


#################################
# Optional weekly cleanup rule
#################################
resource "aws_cloudwatch_event_rule" "weekly_cleanup" {
  name                = "WeeklyCleanupRule"
  schedule_expression = "rate(7 days)"
  tags                = var.project_tags
}

resource "aws_cloudwatch_event_target" "cleanup_target" {
  rule      = aws_cloudwatch_event_rule.weekly_cleanup.name
  target_id = "CleanupLambda"
  arn       = aws_lambda_function.register_face.arn
}

resource "aws_lambda_permission" "allow_events" {
  statement_id  = "AllowEventsInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.register_face.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.weekly_cleanup.arn
}
