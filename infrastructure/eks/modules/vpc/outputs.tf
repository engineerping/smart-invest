# VPC 模块 - 输出变量

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "公有子网 ID 列表"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "私有子网 ID 列表（EKS Worker 节点用）"
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "数据库子网 ID 列表（Aurora、Redis、MQ 用）"
  value       = aws_subnet.database[*].id
}

output "vpc_cidr_block" {
  description = "VPC 的 CIDR 地址块"
  value       = aws_vpc.main.cidr_block
}
