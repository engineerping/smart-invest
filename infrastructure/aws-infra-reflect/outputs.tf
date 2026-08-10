output "cloudfront_domain" {
  description = "CloudFront 访问域名"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "ec2_public_ip" {
  description = "EC2 公网 IP"
  value       = aws_instance.smart_invest_server.public_ip
}

output "ec2_public_dns" {
  description = "EC2 公网 DNS"
  value       = aws_instance.smart_invest_server.public_dns
}

output "s3_bucket_name" {
  description = "前端 S3 Bucket 名称"
  value       = aws_s3_bucket.frontend.bucket
}

output "cloudfront_distribution_id" {
  description = "CloudFront Distribution ID（用于缓存刷新）"
  value       = aws_cloudfront_distribution.main.id
}
