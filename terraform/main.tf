data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  # GPU DLC for G/P/Inf classes; CPU DLC otherwise.
  is_gpu        = can(regex("^ml[.](g|p|inf)[.]", var.instance_type))
  dlc_image_tag = local.is_gpu ? var.dlc_image_tag_gpu : var.dlc_image_tag_cpu
  container_image = format(
    "%s.dkr.ecr.%s.amazonaws.com/%s:%s",
    var.dlc_ecr_account_id,
    data.aws_region.current.name,
    var.dlc_image_repository,
    local.dlc_image_tag
  )
}

resource "aws_sagemaker_model" "hf" {
  name               = "${var.name_prefix}-model"
  execution_role_arn = var.execution_role_arn

  primary_container {
    image = local.container_image
    environment = {
      HF_MODEL_ID = var.hf_model_id
      HF_TASK     = var.hf_task
    }
  }
}

resource "aws_sagemaker_endpoint_configuration" "hf" {
  name = "${var.name_prefix}-epc"

  production_variants {
    variant_name           = "primary"
    model_name             = aws_sagemaker_model.hf.name
    initial_instance_count = var.initial_instance_count
    instance_type          = var.instance_type
  }
}

resource "aws_sagemaker_endpoint" "hf" {
  name                 = "${var.name_prefix}-ep"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.hf.name
}
