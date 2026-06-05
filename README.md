# AWS DevOps POC - 极简版 CI/CD 实践

基于 GitHub Actions + Terraform + AWS ECS Fargate 的极简 DevOps 练习项目。

## 仓库结构

```
aws-devops-githubaction/
├── .github/
│   └── workflows/
│       ├── 0-hello-world.yml    # 最简单的Hello World流水线（先跑通这个）
│       ├── 1-ci-build-push.yml  # CI流水线：拉代码→构建→扫描→推ECR
│       └── 2-cd-deploy-ecs.yml  # CD流水线：拉镜像→部署到ECS Fargate
├── infra/
│   ├── main.tf                  # 所有Terraform代码（单文件，无模块）
│   ├── variables.tf             # 变量定义
│   └── outputs.tf               # 输出结果
├── app/
│   ├── index.js                 # Node.js Hello World服务
│   ├── package.json
│   └── Dockerfile               # 极简Dockerfile
└── README.md                    # 本文件
```

## 核心技术栈

| 组件 | 技术 |
|------|------|
| CI/CD 流水线 | GitHub Actions |
| 基础设施即代码 | Terraform |
| 容器镜像仓库 | Amazon ECR |
| 容器运行平台 | Amazon ECS Fargate |
| 日志监控 | Amazon CloudWatch |
| 安全扫描 | Trivy |
| 业务应用 | Node.js |

---

## 一步一步跑通流程

### 前期准备

#### 1. 安装本地工具

```bash
# 验证工具是否已安装
git --version
terraform --version
aws --version
```

#### 2. 配置 AWS CLI 本地凭证

```bash
aws configure
# 依次输入：
# AWS Access Key ID: <你的AccessKeyID>
# AWS Secret Access Key: <你的SecretAccessKey>
# Default region name: us-east-1
# Default output format: json
```

#### 3. 查询你的 VPC 和子网 ID

```bash
# 查询默认VPC ID
aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text

# 查询默认VPC的公共子网ID列表
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=<上面查到的VPC_ID>" \
  --query "Subnets[*].SubnetId" \
  --output text
```

#### 4. 修改 Terraform 变量

编辑 `infra/variables.tf`，替换以下占位符：

```hcl
variable "vpc_id" {
  default = "vpc-xxxxxxxxxxxxxxxxx"  # ← 替换成你的VPC ID
}

variable "public_subnet_ids" {
  default = ["subnet-xxxxxxxxxxxxxxxxx", "subnet-xxxxxxxxxxxxxxxxx"]  # ← 替换成你的子网ID
}
```

#### 5. 在 GitHub 仓库配置 Secrets

进入仓库 **Settings → Secrets and variables → Actions → New repository secret**，添加以下 6 个 Secrets：

| Secret 名称 | 说明 | 示例值 |
|-------------|------|--------|
| `AWS_ACCESS_KEY_ID` | AWS 访问密钥 ID | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS 秘密访问密钥 | `wJalrXUtnFEMI/K7MDENG/...` |
| `AWS_REGION` | AWS 区域 | `us-east-1` |
| `ECR_REPO_NAME` | ECR 仓库名称 | `devops-poc-repo` |
| `ECS_CLUSTER_NAME` | ECS 集群名称 | `devops-poc-cluster` |
| `ECS_SERVICE_NAME` | ECS 服务名称 | `devops-poc-service` |

---

### 第一步：运行 Hello World 流水线

1. 将所有文件提交并推送到 GitHub：
   ```bash
   git add .
   git commit -m "feat: 初始化DevOps POC项目"
   git push origin main
   ```

2. 进入仓库的 **Actions** 页面

3. 找到 **0. Hello World 入门流水线**，点击 **Run workflow**

4. 等待运行完成，查看日志，确认输出了 Hello World ✅

---

### 第二步：用 Terraform 创建 AWS 基础设施

```bash
# 进入infra目录
cd infra

# 初始化Terraform（下载AWS Provider）
terraform init

# 查看执行计划（确认要创建的资源）
terraform plan

# 应用配置（输入 yes 确认）
terraform apply
```

等待约 **5 分钟**，以下资源将被创建：
- ✅ ECR 镜像仓库（`devops-poc-repo`）
- ✅ CloudWatch 日志组（`/ecs/devops-poc`）
- ✅ IAM 任务执行角色
- ✅ ECS 集群（`devops-poc-cluster`）
- ✅ ECS 任务定义
- ✅ ECS Fargate 服务 + 安全组

**重要**：将生成的 `task-definition.json` 提交到 GitHub（CD 流水线需要用）：

```bash
cd ..
git add infra/task-definition.json
git commit -m "feat: 添加ECS任务定义文件"
git push origin main
```

---

### 第三步：触发 CI 流水线构建并推送镜像

修改 `app/index.js` 中的文字触发自动构建：

```javascript
// 改成这样
res.end('Hello DevOps v2! 我的第一个ECS服务跑通了！🎉\n');
```

```bash
git add app/index.js
git commit -m "feat: 更新应用版本到v2"
git push origin main
```

进入 **Actions** 页面，会自动触发 **1. CI 构建并推送镜像到ECR** 流水线。

流水线步骤：
1. 检出代码
2. 配置 AWS 凭证
3. 登录 ECR
4. **Trivy 安全扫描**（发现 CRITICAL/HIGH 漏洞会失败）
5. 构建 Docker 镜像（标签为 Git commit SHA）
6. 推送镜像到 ECR ✅

---

### 第四步：触发 CD 流水线部署到 ECS

1. 在 **Actions** 页面找到 **2. CD 部署到ECS Fargate**

2. 点击 **Run workflow**，保持默认的 `latest` 标签

3. 等待约 **3 分钟**，部署完成

4. 查看公网 IP：
   - 进入 **AWS 控制台 → ECS → 集群 → devops-poc-cluster**
   - 点击 **服务 → devops-poc-service → 任务**
   - 点击任务 ID → 找到 **公网 IP**

5. 浏览器访问 `http://<公网IP>:3000`，看到 Hello World 就成功了！🎉

---

### 第五步：验证监控日志

打开 Terraform 输出的 CloudWatch 日志组地址（运行 `terraform output` 查看）：

```bash
cd infra
terraform output cloudwatch_log_group_url
```

在 CloudWatch 控制台查看日志流，确认能看到 Node.js 服务的启动日志。

---

## 清理资源（避免产生费用）

练习完成后，销毁所有 AWS 资源：

```bash
cd infra
terraform destroy
# 输入 yes 确认
```

---

## 常见问题

**Q: CI 流水线 Trivy 扫描失败怎么办？**
A: `node:20-alpine` 镜像通常没有高危漏洞。如果扫描失败，检查是否有其他依赖包引入了漏洞。

**Q: ECS 服务启动失败怎么办？**
A: 检查 CloudWatch 日志组 `/ecs/devops-poc` 中的错误信息，常见原因是 ECR 镜像不存在（需要先跑 CI 流水线推送镜像）。

**Q: terraform apply 报错 VPC 不存在？**
A: 确认已将 `variables.tf` 中的 `vpc_id` 和 `public_subnet_ids` 替换成你账号中真实的 VPC 和子网 ID。

**Q: GitHub Actions 报错 AWS 凭证无效？**
A: 检查 GitHub Secrets 中的 `AWS_ACCESS_KEY_ID` 和 `AWS_SECRET_ACCESS_KEY` 是否正确配置，且对应的 IAM 用户有足够权限。
