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
  profile = var.aws_profile # 缺省值为 default
  region = var.aws_region
}

# WAF Web ACL 必须部署在 us-east-1（CloudFront 全局）
provider "aws" { #Terraform 允许同一个 Provider 类型出现多次，通过 alias 来区分。无 alias 的那个是默认 provider，有 alias 的需要在资源中显式引用。
  profile = var.aws_profile
  alias   = "us_east_1"
  region  = "us-east-1"
}
