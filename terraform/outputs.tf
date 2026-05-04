output "endpoint_name" {
  description = "SageMaker real-time endpoint name (use with invoke_endpoint.py or AWS CLI)."
  value       = aws_sagemaker_endpoint.hf.name
}

output "endpoint_arn" {
  description = "ARN of the SageMaker endpoint."
  value       = aws_sagemaker_endpoint.hf.arn
}

output "model_name" {
  value = aws_sagemaker_model.hf.name
}

output "endpoint_configuration_name" {
  value = aws_sagemaker_endpoint_configuration.hf.name
}

output "container_image" {
  description = "DLC image URI used for the model container."
  value       = local.container_image
}

output "region" {
  value = data.aws_region.current.name
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}
