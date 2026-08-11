# ==============================================================================
# IAM 模块 —— 输出变量
# ==============================================================================

output "role_name" {
  description = "IAM Role 名称（用于在其他模块中引用）"
  value       = aws_iam_role.ec2_role.name
}

output "role_arn" {
  description = "IAM Role 的 ARN（全局唯一标识符，如给其他 AWS 服务引用时需要）"
  value       = aws_iam_role.ec2_role.arn
}

output "instance_profile_name" {
  description = "IAM Instance Profile 名称（传给 EC2 模块，让 EC2 获得角色权限）"
  value       = aws_iam_instance_profile.ec2_profile.name
}
