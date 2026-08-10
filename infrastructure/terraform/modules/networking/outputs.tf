# ==============================================================================
# Networking 模块 —— 输出变量
# ==============================================================================
# Output 是模块的"返回值"，被根模块（live/prod/main.tf）引用。
#
# 引用方式：module.networking.vpc_id → "vpc-xxxxx"
# ==============================================================================

output "vpc_id" {
  description = "默认 VPC 的 ID"
  value       = data.aws_vpc.default.id
}

output "public_subnet_id" {
  description = "公有子网的 ID（EC2 部署在此子网中）"
  value       = data.aws_subnet.public.id
}

output "security_group_id" {
  description = "安全组的 ID（用于绑定到 EC2）"
  value       = aws_security_group.smart_invest.id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID（调试用）"
  value       = data.aws_internet_gateway.default.id
}
