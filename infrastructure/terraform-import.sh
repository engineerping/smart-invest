#!/bin/bash

# Execute this shell script in directory smart-invest/infrastructure/aws-infra-reflect
set -e

echo "🚀 开始导入 AWS 资源到 Terraform 状态..."

echo "📦 [1/9] 导入 S3 Bucket..."
terraform import aws_s3_bucket.frontend \
  smart-invest-frontend-service-prod-bucket-name

echo "📦 [2/9] 导入 S3 Public Access Block..."
terraform import aws_s3_bucket_public_access_block.frontend \
  smart-invest-frontend-service-prod-bucket-name

echo "📦 [3/9] 导入 S3 Versioning..."
terraform import aws_s3_bucket_versioning.frontend \
  smart-invest-frontend-service-prod-bucket-name

echo "🔒 [4/9] 导入 Security Group..."
terraform import aws_security_group.smart_invest \
  sg-069cbdca5e023f0cb

echo "👤 [5/9] 导入 IAM Role..."
terraform import aws_iam_role.ec2_role \
  smart-invest-ec2-role

echo "👤 [6/9] 导入 IAM Instance Profile..."
terraform import aws_iam_instance_profile.ec2_profile \
  smart-invest-ec2-role

echo "🖥️  [7/9] 导入 EC2 Instance..."
terraform import aws_instance.smart_invest_server \
  i-024897e5a18af2a8c

echo "🛡️  [8/9] 导入 WAF Web ACL..."
terraform import aws_wafv2_web_acl.cloudfront_waf \
  "arn:aws:wafv2:us-east-1:501264525584:global/webacl/CreatedByCloudFront-398257e2/6d880da8-ad11-41b0-ba70-aa3056eda097"

echo "☁️  [9/9] 导入 CloudFront OAC..."
terraform import aws_cloudfront_origin_access_control.s3_oac \
  EQI4X0RRQW63X

echo "☁️  [10/10] 导入 CloudFront Distribution..."
terraform import aws_cloudfront_distribution.main \
  ES0ZIR6UJOY98

echo "📜 导入 S3 Bucket Policy（需在 CloudFront 之后）..."
terraform import aws_s3_bucket_policy.frontend \
  smart-invest-frontend-service-prod-bucket-name

echo ""
echo "✅ 所有资源导入完成！"
echo "👉 运行 'terraform plan' 查看配置与实际资源的差异"
