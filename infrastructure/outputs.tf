output "ec2_public_ip"     { value = module.ec2.public_ip }
output "instance_id"       { value = module.ec2.instance_id }
output "cloudfront_domain" { value = module.s3_cloudfront.cloudfront_domain }
output "frontend_bucket"   { value = module.s3_cloudfront.bucket_name }
output "db_secret_arn"    { value = module.rds.db_secret_arn }
output "db_endpoint"      { value = module.rds.db_endpoint }
