# ==============================================================================
# Compute 模块 —— 输出变量
# ==============================================================================

output "instance_id" {
  description = "EC2 实例 ID（如 i-0abcd1234），用于 AWS CLI 操作和 CloudWatch 监控"
  value       = aws_instance.k3s_server.id
}

output "public_ip" {
  description = "EC2 公网 IP 地址（EIP，固定不变），用于 SSH 登录和 CloudFront 回源"
  value       = aws_eip.k3s.public_ip
}

output "public_dns" {
  description = "EC2 公网 DNS 名称（如 ec2-xx-xx-xx-xx.compute.amazonaws.com）"
  value       = aws_instance.k3s_server.public_dns
}

output "private_ip" {
  description = "EC2 私有 IP 地址（VPC 内部通信使用）"
  value       = aws_instance.k3s_server.private_ip
}

output "ami_id" {
  description = "当前使用的 AMI ID（记录用，方便排查问题）"
  value       = data.aws_ami.al2023.id
}
