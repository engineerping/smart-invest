variable "aws_region"   { default = "us-east-1" }
variable "environment"  { default = "prod" }
variable "admin_cidr"   { description = "Your IP in CIDR format, e.g. 1.2.3.4/32" }
variable "key_pair_name"{ description = "EC2 SSH key pair name (created in AWS console)" }
variable "account_id"   { description = "AWS account ID" }
