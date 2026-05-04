# Terraform: SageMaker Hugging Face endpoint

Defines:

- `aws_sagemaker_model` — Hugging Face DLC container with `HF_MODEL_ID` / `HF_TASK`
- `aws_sagemaker_endpoint_configuration` — instance type and count
- `aws_sagemaker_endpoint` — real-time inference endpoint

## Commands

From this directory:

```bash
cp terraform.tfvars.example terraform.tfvars   # edit execution_role_arn, etc.
terraform init
terraform plan
terraform apply
terraform output endpoint_name
```

Optional remote state: copy `backend.hcl.example` to `backend.hcl`, create the bucket, then `terraform init -backend-config=backend.hcl` (see root README).

## Naming

Resources use `var.name_prefix` (default `twitter-sentiment-hf`) for the model, endpoint config, and endpoint **names**. Change the prefix if names already exist in your account/region.
