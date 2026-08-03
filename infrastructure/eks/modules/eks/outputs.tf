output "cluster_name" {
  description = "EKS 集群名称"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS API Server 端点"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "EKS 集群 CA 证书"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "oidc_provider_url" {
  description = "OIDC Provider URL（去掉 https:// 前缀）"
  value       = replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")
}

output "oidc_provider_arn" {
  description = "OIDC Provider ARN"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "cluster_token" {
  description = "EKS 集群访问 Token（用于 Helm/K8s Provider）"
  value       = data.aws_eks_cluster_auth.main.token
  sensitive   = true
}

# ALB DNS 由 K8s AWS Load Balancer Controller 动态创建
# 不能在此处获取，cloudfront 模块需要使用占位符或通过 data source 延迟获取
# 方案：CloudFront 先指向 EKS Ingress 的 NLB，NLB DNS 由 K8s 创建后
# 通过 terraform_remote_state 或外部脚本更新
output "alb_dns_name" {
  description = "ALB DNS 名（由 K8s Load Balancer Controller 动态创建后手动填入）"
  value       = var.alb_dns_name_override != "" ? var.alb_dns_name_override : ""
}
