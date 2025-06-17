This folder contains the AWS implementation. For the GCP equivalent see ../gcp.
# Serverless Face Recognition Example

This project demonstrates how to build a facial recognition API on AWS using **Lambda**, **API Gateway**, **S3**, **DynamoDB**, **Rekognition**, and **SNS**. All infrastructure is provisioned with **Terraform**.

## Architecture Overview

- **API Gateway** exposes two endpoints: `/register` and `/recognize`.
- **Lambda Functions** `RegisterFaceFunction` and `RecognizeFaceFunction` handle face registration and recognition.
- **S3 Bucket** `face-images-bucket` stores uploaded images with versioning enabled.
- **Rekognition Collection** `FaceCollection` indexes faces for later searches.
- **DynamoDB Table** `FaceMetadataTable` stores metadata mapping `faceId` to a `userId` and S3 object key.
- **SNS Topic** `FaceRegistrationTopic` publishes notifications when a face is registered.
- **IAM Roles** grant the Lambdas least‑privilege access to S3, Rekognition, DynamoDB, SNS and CloudWatch Logs.

## Files

```
face-recognition-terraform/
├── main.tf              # Infrastructure resources
├── variables.tf         # Input variables
├── outputs.tf           # Useful outputs (API URLs)
├── terraform.tfvars     # Example variable values
├── lambda_register/
│   ├── index.js
│   └── package.json
├── lambda_recognize/
│   ├── index.js
│   └── package.json
└── README.md            # This file
```

## Running Terraform

1. **Install Terraform** – See [terraform.io](https://www.terraform.io/downloads.html).
2. **Configure AWS credentials** (environment variables or shared credentials file):
   ```bash
  export AWS_ACCESS_KEY_ID=...
  export AWS_SECRET_ACCESS_KEY=...
  export AWS_DEFAULT_REGION=us-east-1
  ```
   If your default region does not support Rekognition (e.g., `sa-east-1`),
   edit `terraform.tfvars` and set `rekognition_region` to a supported region
   like `us-east-1` so the Rekognition collection is created there.
3. **Initialize**:
   ```bash
   terraform init
   ```
4. **Review the plan**:
   ```bash
   terraform plan -out=tfplan
   ```
5. **Apply**:
   ```bash
   terraform apply tfplan
   ```
6. After apply completes, Terraform outputs the API Gateway endpoints. Use them with `curl` to test:
   ```bash
   curl -X POST <register_url> \
     -H "Content-Type: application/json" \
     -d '{"userId":"user123","imageBase64":"<BASE64>"}'

   curl -X POST <recognize_url> \
     -H "Content-Type: application/json" \
     -d '{"imageBase64":"<BASE64>"}'
   ```
7. **Inspect Resources** – verify images in S3, records in DynamoDB, and SNS messages in CloudWatch Logs.
8. **Cleanup** when finished:
   ```bash
   terraform destroy -auto-approve
   ```

## Resource Explanations

Each Terraform resource includes comments describing its purpose. Highlights:

- `aws_s3_bucket.face_images` – stores uploaded images with versioning.
- `aws_dynamodb_table.face_metadata` – keeps face metadata with a GSI on `userId`.
- `aws_rekognition_collection.faces` – holds indexed faces for recognition.
- IAM role policies follow the principle of least privilege so Lambdas can only access required resources.
- API Gateway methods integrate with the Lambdas using `AWS_PROXY` to forward the request body directly.
- Outputs expose the invoke URLs so you can easily hit the endpoints.

Terraform automatically manages dependencies. For example, the API deployment waits for methods and integrations using `depends_on`, and Lambda policies reference resources that must exist before they can be attached.

