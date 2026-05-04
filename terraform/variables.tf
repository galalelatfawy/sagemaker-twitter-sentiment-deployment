variable "aws_region" {
  type        = string
  description = "AWS region for SageMaker resources."
  default     = "us-east-1"
}

variable "execution_role_arn" {
  type        = string
  description = "IAM role ARN SageMaker assumes to pull images, write logs, and access optional resources (Hub models need ECR/CloudWatch)."
}

variable "name_prefix" {
  type        = string
  description = "Prefix for SageMaker resource names."
  default     = "twitter-sentiment-hf"
}

variable "hf_model_id" {
  type        = string
  description = "Hugging Face Hub model id."
  default     = "cardiffnlp/twitter-roberta-base-sentiment-latest"
}

variable "hf_task" {
  type        = string
  description = "HF_TASK passed to the inference container."
  default     = "text-classification"
}

variable "instance_type" {
  type        = string
  description = "Instance type for the real-time endpoint."
  default     = "ml.g6.2xlarge"
}

variable "initial_instance_count" {
  type        = number
  description = "Number of instances behind the endpoint."
  default     = 1
}

variable "dlc_ecr_account_id" {
  type        = string
  description = "AWS account id hosting DLC images in this partition (763104351884 in most commercial regions)."
  default     = "763104351884"
}

variable "dlc_image_repository" {
  type        = string
  description = "ECR repository name for Hugging Face PyTorch inference DLC."
  default     = "huggingface-pytorch-inference"
}

variable "dlc_image_tag_gpu" {
  type        = string
  description = "Image tag for GPU instances (g/p/inf families)."
  default     = "2.6.0-transformers4.51.3-gpu-py312-cu124-ubuntu22.04"
}

variable "dlc_image_tag_cpu" {
  type        = string
  description = "Image tag for CPU-only instances."
  default     = "2.6.0-transformers4.51.3-cpu-py312-ubuntu22.04"
}

variable "tags" {
  type        = map(string)
  description = "Default provider tags for supported resources."
  default     = {}
}
