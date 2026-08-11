# ==============================================================================
# 输出变量 —— 部署后打印有用信息
# ==============================================================================
# terraform apply 完成后会自动显示这些信息。
# 也可以在部署后随时查看：
#   terraform output                  # 查看所有输出
#   terraform output ec2_public_ip    # 查看单个输出
#   terraform output -json            # JSON 格式（CI/CD 脚本用）
# ==============================================================================

output "ec2_public_ip" {
  description = "EC2 公网 IP（EIP，固定不变）。使用方式：ssh ec2-user@<此IP>"
  value       = module.compute.public_ip
}

output "ec2_public_dns" {
  description = "EC2 公网 DNS 名称（用于 CloudFront 回源和 DNS CNAME 配置）"
  value       = module.compute.public_dns
}

output "ec2_instance_id" {
  description = "EC2 实例 ID（用于 AWS Console 定位和 awscli 操作，如 aws ec2 reboot --instance-ids i-xxx）"
  value       = module.compute.instance_id
}

output "cloudfront_domain" {
  description = "CloudFront 分发域名（前端访问入口，如 d123456.cloudfront.net）"
  value       = module.cdn.cloudfront_domain
}

output "cloudfront_distribution_id" {
  description = "CloudFront Distribution ID（用于缓存刷新：aws cloudfront create-invalidation --distribution-id <此ID> --paths '/*'）"
  value       = module.cdn.cloudfront_distribution_id
}

output "s3_bucket_name" {
  description = "前端 S3 存储桶名称（用于部署前端：aws s3 sync dist/ s3://<此名称>/）"
  value       = module.cdn.s3_bucket_name
}

output "ec2_ssh_command" {
  description = "SSH 登录命令（直接复制粘贴到终端）"
  value       = "ssh ec2-user@${module.compute.public_ip}"
}

output "website_url" {
  description = "网站访问地址"
  value       = "https://${module.cdn.cloudfront_domain}"
}
