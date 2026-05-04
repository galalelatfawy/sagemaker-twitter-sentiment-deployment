# sagemaker-twitter-sentiment-terraform

This project deploys a **Hugging Face** text-classification model to **Amazon SageMaker** real-time inference using **Terraform** for infrastructure. The default model is [cardiffnlp/twitter-roberta-base-sentiment-latest](https://huggingface.co/cardiffnlp/twitter-roberta-base-sentiment-latest) (RoBERTa sentiment on short text).

**GitHub repository name:** `sagemaker-twitter-sentiment-terraform` (configure under **Settings → General → Repository name**). See [Rename on GitHub](#rename-on-github) if you still use an older name.

## What this solution does

- **Provisions** a SageMaker **model**, **endpoint configuration**, and **endpoint** with the [Hugging Face PyTorch inference DLC](https://huggingface.co/docs/sagemaker/main) (container env: `HF_MODEL_ID`, `HF_TASK`). Default DLC tags match PyTorch **2.6.0** / Transformers **4.51.3** / Python **3.12**; GPU vs CPU image is chosen from `instance_type` (e.g. `ml.g6.2xlarge` → GPU).
- **Invokes** the live endpoint with a small Python helper ([`invoke_endpoint.py`](invoke_endpoint.py)) or the AWS CLI / any AWS SDK.
- **Supports GitHub Actions** with **OpenID Connect (OIDC)** into AWS (no long-lived access keys in GitHub).
- **Uses two IAM roles** (recommended): a **deploy** role for Terraform / CI (SageMaker APIs + `PassRole`), and a **SageMaker execution role** used by the running endpoint (ECR pull, CloudWatch Logs, etc.).

```text
Terraform / CI (deploy role) ──► SageMaker APIs ──► PassRole ──► execution role
                                                                      │
                                                                      ▼
                                                    HF DLC endpoint (RoBERTa sentiment)
```

## Repository layout

| Path | Purpose |
|------|---------|
| [`terraform/`](terraform/) | Root module: `aws_sagemaker_model`, endpoint configuration, endpoint. |
| [`terraform/README.md`](terraform/README.md) | Short Terraform usage notes. |
| [`invoke_endpoint.py`](invoke_endpoint.py) | `boto3` `InvokeEndpoint` smoke / local tests. |
| [`pyproject.toml`](pyproject.toml) / [`uv.lock`](uv.lock) | Python 3.12+; **boto3** only. |
| [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) | Manual `terraform init` + `apply` with OIDC. |
| [`.github/DEPLOYMENT.md`](.github/DEPLOYMENT.md) | OIDC trust policy examples and IAM notes. |

## Prerequisites

- [Terraform](https://www.terraform.io/) `>= 1.5`, [AWS provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) `~> 5` (lock file: `terraform/.terraform.lock.hcl`).
- An AWS **SageMaker execution role** (Terraform variable `execution_role_arn`) with trust for `sagemaker.amazonaws.com` and policies for inference (ECR, CloudWatch, etc.)—see [SageMaker execution roles](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-roles.html).
- **Python 3.12+** and **[uv](https://docs.astral.sh/uv/)** if you use [`invoke_endpoint.py`](invoke_endpoint.py).
- For GitHub Actions: repository **secrets** as below.

## Deploy with Terraform (local)

From [`terraform/`](terraform/):

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # set execution_role_arn, optional name_prefix / region
terraform init
terraform plan
terraform apply
terraform output endpoint_name
```

Configuration highlights (see [`variables.tf`](terraform/variables.tf)):

| Variable | Default | Notes |
|----------|---------|--------|
| `execution_role_arn` | (required) | SageMaker execution role for the **model** resource. |
| `name_prefix` | `twitter-sentiment-hf` | Names: `{prefix}-model`, `{prefix}-epc`, `{prefix}-ep`. Must be unique per account/region. |
| `aws_region` | `us-east-1` | Provider region. |
| `instance_type` | `ml.g6.2xlarge` | GPU → GPU DLC tag; CPU instances → CPU DLC tag. |
| `hf_model_id` / `hf_task` | RoBERTa sentiment / `text-classification` | Container environment. |

**Terraform state:** By default state is **local** `terraform.tfstate`. For teams or CI, use an **S3 backend** (copy [`terraform/backend.hcl.example`](terraform/backend.hcl.example), create the bucket, run `terraform init -backend-config=backend.hcl`). Without remote state, repeated GitHub Actions applies from a clean runner will not see previous state—configure S3 (or Terraform Cloud) before relying on CI apply.

**Destroy** when you are done paying for the endpoint:

```bash
cd terraform && terraform destroy
```

## Invoke the endpoint

After apply, get the name from `terraform output -raw endpoint_name` or the AWS console.

```bash
uv sync
export ENDPOINT_NAME=twitter-sentiment-hf-ep    # your Terraform output
export AWS_REGION=us-east-1
uv run python invoke_endpoint.py
```

Optional: `PREDICT_BODY='{"inputs":"your text"}'` (JSON string).

## Deploy from GitHub Actions

Workflow: **Deploy SageMaker (Terraform)** — manual (`workflow_dispatch`) only.

### Secrets and variables

Same as before (see [`.github/DEPLOYMENT.md`](.github/DEPLOYMENT.md)):

| Kind | Name | Purpose |
|------|------|--------|
| Secret | `AWS_ROLE_ARN` | IAM role GitHub OIDC assumes (**Terraform / deploy** role). |
| Secret | `SAGEMAKER_EXECUTION_ROLE_ARN` | Passed as `TF_VAR_execution_role_arn` (SageMaker **execution** role). |
| Variable (optional) | `AWS_REGION` | Defaults to `us-east-1`. |

The **deploy** role must allow Terraform to manage SageMaker resources (e.g. `CreateModel`, `CreateEndpoint`, `CreateEndpointConfiguration`, `Describe*`, updates/deletes as needed) and **`iam:PassRole`** on the execution role ARN. Exact actions should follow least privilege for your account.

Run: **Actions → Deploy SageMaker (Terraform) → Run workflow.**  
Steps: `terraform init`, `terraform apply`, then an optional **AWS CLI** invoke against the new endpoint.

### CI and Terraform state

Configure an **S3 backend** (and optional DynamoDB lock table) so each workflow run shares state; otherwise every run starts with no state and can conflict or duplicate resources. See [`terraform/backend.hcl.example`](terraform/backend.hcl.example).

## Cost and operations

- Endpoints bill for **instance hours** (`instance_type` × `initial_instance_count`). Use **`terraform destroy`** when finished.
- DLC image URIs use account **`763104351884`** in most commercial regions; other partitions (e.g. GovCloud) need different ECR account IDs—set `dlc_ecr_account_id` if required.

## Troubleshooting

| Issue | What to check |
|-------|----------------|
| OIDC / assume role fails | Trust policy on **deploy** role; OIDC provider; `sub` claim. |
| `PassRole` denied | Deploy role may pass only **execution** role used in `execution_role_arn`. |
| Wrong DLC / startup failures | Align `dlc_image_tag_*` with [Available DLCs](https://huggingface.co/docs/sagemaker/main/en/dlcs/available) and your `instance_type` (GPU vs CPU). |
| Name already exists | Change `name_prefix` or remove old resources in SageMaker / state. |

## Rename on GitHub

The intended repository name is **`sagemaker-twitter-sentiment-terraform`**. Renaming is done in the GitHub UI (this cannot be changed from the files in the repo alone).

1. On GitHub: open the repository → **Settings** → **General** → **Repository name** → set to `sagemaker-twitter-sentiment-terraform` → **Rename**.
2. On your machine, point `origin` at the new URL (GitHub redirects the old URL for a while, but update when you can):

   ```bash
   git remote set-url origin https://github.com/<YOUR_USER_OR_ORG>/sagemaker-twitter-sentiment-terraform.git
   ```

3. If you already configured **AWS OIDC** for GitHub Actions, update the deploy role’s trust policy so the `sub` condition matches the new repo name, e.g. `repo:<OWNER>/sagemaker-twitter-sentiment-terraform:*` (see [`.github/DEPLOYMENT.md`](.github/DEPLOYMENT.md)).
4. With the [GitHub CLI](https://cli.github.com/): `gh repo rename sagemaker-twitter-sentiment-terraform` (run from a clone, with `gh auth login` done).
