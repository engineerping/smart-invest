# =============================================================================
# 根模块输出变量
# =============================================================================
# Output 是 Terraform 模块的"返回值"，类比 Java 方法的 return。
# 用途：
#   1. 部署后查看关键信息：terraform output <name>
#   2. 被父模块引用：其他模块可以通过 module.xxx.<output_name> 获取值
#   3. 传递给外部系统：CI/CD pipeline 可以用 terraform output -json 获取自动化所需的值
# =============================================================================

# -------------------------------------------------------------------
# ec2_public_ip: EC2 弹性公网 IP
# 用途：SSH 登录（ssh ec2-user@<ip>）、访问应用（http://<ip>:8080）
# -------------------------------------------------------------------
output "ec2_public_ip"     { value = module.ec2.public_ip }

# -------------------------------------------------------------------
# instance_id: EC2 实例 ID（如 i-0abcd1234）
# 用途：AWS Console 定位实例、CloudWatch 监控查询、awscli 操作
# -------------------------------------------------------------------
output "instance_id"       { value = module.ec2.instance_id }

# -------------------------------------------------------------------
# cloudfront_domain: CloudFront 分发域名（如 d123.cloudfront.net）
# 用途：前端访问地址，可配置 CNAME 指向自定义域名
# -------------------------------------------------------------------
output "cloudfront_domain" { value = module.s3_cloudfront.cloudfront_domain }

# -------------------------------------------------------------------
# frontend_bucket: S3 Bucket 名称
# 用途：上传前端静态文件（aws s3 sync dist/ s3://<bucket>）
# -------------------------------------------------------------------
output "frontend_bucket"   { value = module.s3_cloudfront.bucket_name }

# -------------------------------------------------------------------
# db_secret_arn: 数据库密码在 Secrets Manager 中的 ARN
# 用途：应用启动时从 Secrets Manager 获取数据库密码
# -------------------------------------------------------------------
output "db_secret_arn"    { value = module.rds.db_secret_arn }

# -------------------------------------------------------------------
# db_endpoint: RDS 数据库连接端点（如 xxx.us-east-1.rds.amazonaws.com:5432）
# 用途：应用配置中的数据库连接地址
# -------------------------------------------------------------------
output "db_endpoint"      { value = module.rds.db_endpoint }
