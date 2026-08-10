# =============================================================================
# terraform-k3s 输出变量
# =============================================================================
# 部署后可以用 terraform output 查看这些值（类比 Java 方法的返回值）。
#
# 常用命令：
#   - terraform output                  → 列出所有 output
#   - terraform output <name>           → 查看单个 output 的值
#   - terraform output -json            → JSON 格式输出（供 CI/CD 消费）
#   - terraform output -raw <name>      → 原始字符串（不带引号，适合 shell 脚本）
# =============================================================================

# -------------------------------------------------------------------
# namespace: 应用命名空间
# 用途：kubectl 操作时指定 -n smart-invest
# -------------------------------------------------------------------
output "namespace" {
  value = "smart-invest"
}

# -------------------------------------------------------------------
# user_service_deployment: user-service Deployment 的名称
# 用途：kubectl rollout status deployment/<name> -n smart-invest
# -------------------------------------------------------------------
output "user_service_deployment" {
  description = "user-service Deployment 名称"
  value       = kubernetes_deployment.user_service.metadata[0].name
}

# -------------------------------------------------------------------
# user_service_image: 当前部署的镜像
# 用途：快速查看当前线上版本，方便排查版本问题
# -------------------------------------------------------------------
output "user_service_image" {
  description = "user-service 当前镜像"
  value       = "gongchengship/smart-invest-user-service:${var.image_tag}"
}

# -------------------------------------------------------------------
# usage: 部署后下一步操作指引
# 这是一个帮助性质的输出，告诉使用者部署完成后该做什么。
# 使用 heredoc 语法（<<-EOT）方便写多行文本。
# 注意：缩进必须用 Tab（不能用空格），因为 <<- 只忽略 Tab 缩进。
# -------------------------------------------------------------------
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
