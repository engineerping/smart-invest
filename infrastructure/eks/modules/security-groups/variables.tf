variable "project_name" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "common_tags" { type = map(string) }
variable "ports" { type = map(number) }
variable "admin_cidrs" { type = list(string) }
