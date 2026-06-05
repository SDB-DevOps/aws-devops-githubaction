# infra/main.tf
# 配置AWS Provider
provider "aws" {
  region = var.aws_region
}

# 1. 创建ECR镜像仓库
resource "aws_ecr_repository" "devops_poc" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "MUTABLE" # 允许覆盖latest标签
  image_scanning_configuration {
    scan_on_push = true # 推送时自动扫描漏洞
  }
}

# 2. 创建CloudWatch日志组
resource "aws_cloudwatch_log_group" "devops_poc" {
  name              = "/ecs/devops-poc"
  retention_in_days = 7 # 日志保留7天
  tags = {
    Name = "devops-poc-log-group"
  }
}

# 3. 创建ECS任务执行角色（给ECS拉镜像和写日志用）
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role-poc"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# 附加ECS任务执行策略（最小权限）
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 4. 创建ECS集群
resource "aws_ecs_cluster" "devops_poc" {
  name = var.ecs_cluster_name
}

# 5. 创建ECS任务定义
resource "aws_ecs_task_definition" "devops_poc" {
  family                   = "devops-poc-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" # 最小CPU
  memory                   = "512" # 最小内存
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "devops-poc-container"
      image     = "${aws_ecr_repository.devops_poc.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.devops_poc.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  # 生成任务定义JSON文件，供CD流水线使用
  provisioner "local-exec" {
    command = "echo '${jsonencode(aws_ecs_task_definition.devops_poc)}' > task-definition.json"
  }
}

# 6. 创建ECS Fargate服务
resource "aws_ecs_service" "devops_poc" {
  name            = var.ecs_service_name
  cluster         = aws_ecs_cluster.devops_poc.id
  task_definition = aws_ecs_task_definition.devops_poc.arn
  desired_count   = 1 # 只跑1个实例，省钱

  network_configuration {
    subnets          = var.public_subnet_ids # 用你的默认VPC公共子网
    security_groups  = [aws_security_group.devops_poc.id]
    assign_public_ip = true # 分配公网IP，方便直接访问
  }

  # 自动部署最新任务定义
  force_new_deployment = true
}

# 安全组：开放3000端口给所有IP（测试用，生产要限制）
resource "aws_security_group" "devops_poc" {
  name        = "devops-poc-sg"
  description = "允许3000端口访问"
  vpc_id      = var.vpc_id # 用你的默认VPC ID

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
