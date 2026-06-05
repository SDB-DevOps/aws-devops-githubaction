# infra/variables.tf
variable "aws_region" {
  description = "AWS区域"
  type        = string
  default     = "us-east-1" # 改成你常用的区域
}

variable "ecr_repo_name" {
  description = "ECR仓库名称"
  type        = string
  default     = "devops-poc-repo"
}

variable "ecs_cluster_name" {
  description = "ECS集群名称"
  type        = string
  default     = "devops-poc-cluster"
}

variable "ecs_service_name" {
  description = "ECS服务名称"
  type        = string
  default     = "devops-poc-service"
}

variable "vpc_id" {
  description = "你的默认VPC ID"
  type        = string
  default     = "vpc-xxxxxxxxxxxxxxxxx" # 替换成你的VPC ID
}

variable "public_subnet_ids" {
  description = "你的默认VPC公共子网ID列表"
  type        = list(string)
  default     = ["subnet-xxxxxxxxxxxxxxxxx", "subnet-xxxxxxxxxxxxxxxxx"] # 替换成你的子网ID
}
