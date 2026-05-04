# Deploy workflow: AWS authentication (Terraform)

The workflow [`.github/workflows/deploy.yml`](workflows/deploy.yml) authenticates to AWS using **OpenID Connect (OIDC)** so GitHub Actions never stores long‑lived AWS access keys.

Terraform receives the SageMaker **execution** role via:

- `TF_VAR_execution_role_arn` ← repository secret `SAGEMAKER_EXECUTION_ROLE_ARN`

## GitHub configuration

| Kind | Name | Purpose |
|------|------|--------|
| Secret | `AWS_ROLE_ARN` | IAM role ARN GitHub OIDC assumes (the **deploy / Terraform** role). |
| Secret | `SAGEMAKER_EXECUTION_ROLE_ARN` | IAM role ARN SageMaker uses **inside** the endpoint (`PassRole` target). Passed to Terraform as `execution_role_arn`. Usually **not** the same as `AWS_ROLE_ARN`. |
| Variable (optional) | `AWS_REGION` | Defaults to `us-east-1` if unset; also passed as `TF_VAR_aws_region`. |

## AWS: OIDC provider

If your account does not have it yet, add the IAM OIDC identity provider for GitHub:

- Provider URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`

([Configure GitHub OpenID Connect in AWS](https://docs.github.com/en/actions/how-tos/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services))

## AWS: trust policy (deploy role)

Attach a trust policy to the **deploy** role so only this repository can assume it. Replace `ACCOUNT_ID` and `OWNER` with your AWS account ID and GitHub user or organization. This repository’s slug is **`sagemaker-twitter-sentiment-terraform`** — if you rename the GitHub repo, update the `sub` condition to match.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:OWNER/sagemaker-twitter-sentiment-terraform:*"
        }
      }
    }
  ]
}
```

Tighten `sub` further for least privilege (for example restrict to branch `refs/heads/main` only if your workflow policy supports it).

## AWS: permissions for the deploy role (Terraform)

The deploy role must be allowed to manage the SageMaker resources in [`terraform/main.tf`](../terraform/main.tf) (model, endpoint configuration, endpoint) **and** **`iam:PassRole`** only for the execution role ARN in `SAGEMAKER_EXECUTION_ROLE_ARN`.

Use least-privilege IAM for your organization; typical API families include SageMaker model and endpoint APIs plus `iam:PassRole` scoped to that execution role resource.

The **execution** role must trust SageMaker and include permissions for inference (ECR image pull for DLC, CloudWatch Logs, etc.), per [SageMaker execution roles](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-roles.html).

## Terraform state in CI

GitHub-hosted runners do not persist disk between jobs. For repeatable **`terraform apply`** in Actions, configure a remote **S3** backend (and optional DynamoDB table for locking). See [`terraform/backend.hcl.example`](../terraform/backend.hcl.example) and the root README.

## Local Terraform + AWS credentials

```bash
cd terraform
export AWS_REGION=us-east-1
# Use your normal AWS credential chain (profile, env vars, SSO).
terraform init
terraform apply -var="execution_role_arn=arn:aws:iam::ACCOUNT_ID:role/your-sagemaker-execution-role"
```

Avoid committing secrets or long-lived keys to the repository.
