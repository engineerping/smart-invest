# Istio 模块 - 输出变量
# 本模块通过 Helm 部署 Istio，输出供其他模块引用

output "istio_namespace" {
  description = "Istio 部署的命名空间"
  value       = "istio-system"
}

output "istio_ingress_gateway_name" {
  description = "Istio Ingress Gateway Helm Release 名称"
  value       = helm_release.istio_ingress.name
}
