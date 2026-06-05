# infra/outputs.tf
output "ecr_repository_url" {
  description = "ECR镜像仓库地址"
  value       = aws_ecr_repository.devops_poc.repository_url
}

output "ecs_service_public_ip" {
  description = "ECS服务公网IP（需要等服务启动后在控制台查看）"
  value       = "请在AWS控制台ECS服务的任务详情中查看公网IP"
}

output "cloudwatch_log_group_url" {
  description = "CloudWatch日志组地址"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups/log-group/${aws_cloudwatch_log_group.devops_poc.name}"
}
