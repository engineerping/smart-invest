# VPC 模块 - 输入变量

variable "project_name" {
  description = "项目名称"
  type        = string
}

variable "environment" {
  description = "部署环境"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC 的 CIDR 地址块"
  type        = string
}

variable "availability_zones" {
  description = "可用区列表"
  type        = list(string)
}

variable "common_tags" {
  description = "通用标签"
  type        = map(string)
}

variable "admin_cidr_blocks" {
  description = "管理员 IP 段"
  type        = list(string)
}
