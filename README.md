# Serverless Face Recognition Comparison

This project contains a sample facial recognition API implemented on **AWS** and **GCP**. Each cloud version provisions equivalent resources with Terraform so you can compare services side by side.

```
.
├── terraform/
│   ├── aws/                 # Terraform for AWS
│   └── gcp/                 # Terraform for GCP
├── aws_functions/      # AWS Functions
│   ├── lambda_register/       # AWS Lambda code
│   └── lambda_recognize/      # AWS Lambda code
├── gcp_functions/     # GCP Cloud Function code
│   ├── register/              # Register (GCP)
│   └── recognize/             # Recognize (GCP)
├── tests/           # Tests
│   ├── images/                 # People Images
│   └── payloads/    
└── README.md
```

Both deployments expose `/register` and `/recognize` HTTP endpoints through the respective API gateways. Images are stored with versioning, metadata is kept in a database (DynamoDB or Firestore), and notifications are sent (SNS or Pub/Sub).

## Deploying on AWS
1. Install [Terraform](https://www.terraform.io/downloads.html).
2. Configure AWS credentials:
    ```bash
    export AWS_ACCESS_KEY_ID=...
    export AWS_SECRET_ACCESS_KEY=...
    export AWS_DEFAULT_REGION=us-east-1
    ```
    Rekognition isn't available in every region (for example `sa-east-1`). If your
    default region lacks Rekognition, set `rekognition_region` in `terraform.tfvars`
    to a supported region such as `us-east-1`.

    If Terraform reports `AuthorizationHeaderMalformed` while creating the S3
    bucket, adjust the `region` variable in `terraform.tfvars` (and your
    `AWS_DEFAULT_REGION`) so they match the region where your credentials are
    configured, for example `eu-central-1`.
3. Deploy:
    ```bash
    cd terraform/aws
    terraform init
    terraform plan -out aws-plan.tfplan
    terraform apply "aws-plan.tfplan"
    ```
4. After apply, note the outputs for `register_endpoint` and `recognize_endpoint`.
5. Test:
    ```bash
    # Register
    curl -X POST $(terraform output -raw register_endpoint) \
      -H "Content-Type: application/json" \
      -d @../../tests/payloads/register_payload.json
    
    # Recognize
    curl -X POST $(terraform output -raw recognize_endpoint) \
      -H "Content-Type: application/json" \
      -d @../../tests/payloads/recognize_payload.json
    ```
6. Destroy resources when finished:
    ```bash
    terraform destroy -auto-approve
    ```

## Deploying on GCP
1. Install Terraform and authenticate with GCP:
    ```bash
    gcloud auth application-default login
    ```
2. Deploy:
    ```bash
    cd terraform/gcp
    terraform init
    terraform plan -out gcp-plan.tfplan
    terraform apply "gcp-plan.tfplan"
    ```
3. Retrieve outputs:
    ```bash
    terraform output gcp_register_function_url
    terraform output gcp_recognize_function_url
    terraform output gcp_api_gateway_url
    ```
4. Example tests:
    ```bash
    # Direct Cloud Function
    # Register
    curl -X POST $(terraform output -raw gcp_register_function_url) \
      -H "Content-Type: application/json" \
      -d @../../tests/payloads/register_payload.json
    
    # Recognize
    curl -X POST $(terraform output -raw gcp_recognize_function_url) \
      -H "Content-Type: application/json" \
      -d @../../tests/payloads/recognize_payload.json

    # Via API Gateway
    curl -X POST https://$(terraform output -raw gcp_api_gateway_url)/register \
      -H "Content-Type: application/json" \
      -d @../../tests/payloads/register_payload.json
    ```
5. Destroy resources when finished:
    ```bash
    terraform destroy -auto-approve
    ```

## Notes
- AWS uses Lambda, API Gateway, S3, DynamoDB, Rekognition and SNS.
- GCP uses Cloud Functions, API Gateway, Cloud Storage, Vision API, Firestore and Pub/Sub.
- Terraform files include comments explaining each resource and the principle of least privilege IAM roles.
