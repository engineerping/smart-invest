# =============================================================================
# terraform-k3s 输出变量
# =============================================================================
# 部署后可以用 terraform output 查看这些值（类比 Java 方法的返回值）。
# =============================================================================

output "namespace" {
  value = "smart-invest"
}

output "user_service_deployment" {
  description = "user-service Deployment 名称"
  value       = kubernetes_deployment.user_service.metadata[0].name
}

output "user_service_image" {
  description = "user-service 当前镜像"
  value       = "gongchengship/smart-invest-user-service:${var.image_tag}"
}

output "usage" {
  description = "下一步指引"
  value = <<-EOT
    1. 复制服务器的 k3s.yaml 到本地：
       sshpass -p 'George0' scp george@192.168.31.192:/etc/rancher/k3s/k3s.yaml ~/.kube/k3s.yaml
    2. 指定 kubeconfig 执行：
       KUBECONFIG=~/.kube/k3s.yaml terraform plan
       KUBECONFIG=~/.kube/k3s.yaml terraform apply
  EOT
}
