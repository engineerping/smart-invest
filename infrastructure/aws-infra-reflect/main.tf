terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# WAF Web ACL 必须部署在 us-east-1（CloudFront 全局）
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
