# 使用账号默认 VPC
data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "public" {
  id = "subnet-09d50013c6f6a2606"
}

data "aws_internet_gateway" "default" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
