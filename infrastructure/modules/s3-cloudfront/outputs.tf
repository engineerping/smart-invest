# =============================================================================
# S3 + CloudFront 模块输出变量
# =============================================================================

# -------------------------------------------------------------------
# cloudfront_domain: CloudFront 分发域名
#
# 格式：<random-string>.cloudfront.net
# 例如：d12345abcde.cloudfront.net
#
# 这是前端应用的访问地址。HTTP 访问会自动重定向到 HTTPS。
# 前端文件更新后，需要执行缓存失效（Invalidation）让 CDN 节点刷新：
#   aws cloudfront create-invalidation --distribution-id <id> --paths "/*"
#
# 第一个请求会很慢（CDN 缓存未命中，需要回源 S3），后续请求会很快。
# -------------------------------------------------------------------
output "cloudfront_domain" { value = aws_cloudfront_distribution.frontend.domain_name }

# -------------------------------------------------------------------
# bucket_name: S3 Bucket 名称
#
# 用于上传前端构建产物：
#   aws s3 sync dist/ s3://<bucket_name>/ --delete
#   --delete 参数：删除 S3 中有但本地没有的文件（保持同步）
#
# 也可以配合 CI/CD（GitHub Actions/GitLab CI）自动部署：
#   - 代码推送 → CI 构建 → npm build → aws s3 sync → CloudFront invalidation
# -------------------------------------------------------------------
output "bucket_name"       { value = aws_s3_bucket.frontend.bucket }
