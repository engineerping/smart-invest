# ==============================================================================
# CDN 模块 —— 输出变量
# ==============================================================================

output "cloudfront_domain" {
  description = "CloudFront 分发域名（如 d123456.cloudfront.net），前端访问入口"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront Distribution ID（用于缓存刷新：aws cloudfront create-invalidation）"
  value       = aws_cloudfront_distribution.main.id
}

output "s3_bucket_name" {
  description = "S3 存储桶名称（用于前端部署：aws s3 sync dist/ s3://<bucket>/）"
  value       = aws_s3_bucket.frontend.bucket
}

output "s3_bucket_arn" {
  description = "S3 存储桶 ARN（用于 IAM Policy 引用）"
  value       = aws_s3_bucket.frontend.arn
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL 的 ARN（用于 CloudWatch 告警等）"
  value       = data.aws_wafv2_web_acl.cloudfront_waf.arn
}
