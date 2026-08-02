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

output "alb_dns_name" {
  description = "AWS Load Balancer Controller 的 ALB DNS 名（占位，实际由 K8s 创建）"
  value       = ""  # 由 K8s Load Balancer Controller 动态创建
}

data "aws_eks_cluster_auth" "main" {
  name = aws_eks_cluster.main.name
}
