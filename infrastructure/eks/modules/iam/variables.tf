variable "project_name" { type = string }
variable "environment" { type = string }
variable "common_tags" { type = map(string) }
variable "oidc_provider_url" { type = string }
variable "oidc_provider_arn" { type = string }
