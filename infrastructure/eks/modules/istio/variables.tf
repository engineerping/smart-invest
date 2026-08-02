variable "eks_cluster_name" { type = string }
variable "eks_cluster_endpoint" { type = string }
variable "eks_cluster_ca_cert" { type = string }
variable "eks_cluster_token" { type = string }

# 当 Helm 需要时默认的域名
variable "domain_name" {
  type    = string
  default = "smart-invest.example.com"
}
