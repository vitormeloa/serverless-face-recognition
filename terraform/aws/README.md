# AWS Deployment

This directory contains Terraform code to deploy the AWS version of the face recognition API.

## Usage
1. Configure your AWS credentials and default region (defaults to `sa-east-1`).
   ```bash
   export AWS_ACCESS_KEY_ID=YOUR_KEY
   export AWS_SECRET_ACCESS_KEY=YOUR_SECRET
   export AWS_DEFAULT_REGION=sa-east-1
   ```
   Adjust the `region` and `rekognition_region` variables in `terraform.tfvars` if you need another region.
2. Initialize Terraform and apply the configuration:
   ```bash
   terraform init
   terraform apply
   ```

The Lambda source code is located in `aws_functions/register/` and `aws_functions/recognize/`. After apply completes, note the `register_endpoint` and `recognize_endpoint` outputs. You can test them with the payloads in `../../tests/payloads/`:

```bash
curl -X POST $(terraform output -raw register_endpoint) \
  -H "Content-Type: application/json" \
  -d @../../tests/payloads/register_payload.json

curl -X POST $(terraform output -raw recognize_endpoint) \
  -H "Content-Type: application/json" \
  -d @../../tests/payloads/recognize_payload.json
```

Destroy the resources when done:
```bash
terraform destroy -auto-approve
```
