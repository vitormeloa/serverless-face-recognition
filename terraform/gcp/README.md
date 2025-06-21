# GCP Deployment

Terraform scripts in this directory deploy the GCP version of the API.

## Usage
1. Authenticate with Google Cloud and set your project ID:
   ```bash
   gcloud auth application-default login
   gcloud config set project YOUR_PROJECT_ID
   ```
2. Initialize Terraform and apply the configuration:
   ```bash
   terraform init
   terraform apply
   ```

The Cloud Function sources live in `gcp_functions/register/` and `gcp_functions/recognize/`. After the apply finishes, Terraform outputs the function URLs. Test them using the payloads in `../../tests/payloads/`:

```bash
curl -X POST $(terraform output -raw gcp_register_function_url) \
  -H "Content-Type: application/json" \
  -d @../../tests/payloads/register_payload.json

curl -X POST $(terraform output -raw gcp_recognize_function_url) \
  -H "Content-Type: application/json" \
  -d @../../tests/payloads/recognize_payload.json
```

To remove the resources:
```bash
terraform destroy -auto-approve
```
