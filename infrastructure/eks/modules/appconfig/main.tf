# =============================================================================
# AppConfig 模块 - 应用动态配置管理
# =============================================================================
# AWS AppConfig 是 AWS Systems Manager 的一部分
# 用于管理应用的动态配置（Feature Flags、业务参数等）
#
# 与 Spring Cloud Config 的对比：
#   1. AWS 原生服务，不需要自己维护 Config Server
#   2. 支持参数校验：新配置发布前自动验证
#   3. 支持渐进式发布：10% → 50% → 100%
#   4. 自动回滚：如果监控到错误率上升，自动回滚到上一个版本
#
# 在本项目中的用途：
#   - Feature Flags：控制新功能逐步上线
#   - 业务参数：费率、限额等可动态调整

resource "aws_appconfig_application" "main" {
  name        = "${var.project_name}-${var.environment}"
  description = "Smart Invest 应用配置 - ${var.environment}"

  tags = var.common_tags
}

# 配置环境（对应 Spring 的 profile）
resource "aws_appconfig_environment" "main" {
  application_id = aws_appconfig_application.main.id
  name           = var.environment
  description    = "${var.environment} 环境配置"

  # 监控器：当配置变更导致 CloudWatch 告警时自动回滚
  # 这是 AppConfig 的核心安全特性
  monitor {
    alarm_arn      = aws_cloudwatch_metric_alarm.config_rollback.arn
    alarm_role_arn = aws_iam_role.appconfig_monitor.arn
  }

  tags = var.common_tags
}

# 配置档案（配置文件的定义）
resource "aws_appconfig_configuration_profile" "main" {
  application_id = aws_appconfig_application.main.id
  name           = "application-config"
  description    = "Smart Invest Spring Boot 应用配置"
  location_uri   = "hosted"  # 配置文件托管在 AppConfig 中

  # 校验器：在发布前检查 JSON 格式是否合法
  validator {
    type    = "JSON_SCHEMA"
    content = jsonencode({
      "$schema": "http://json-schema.org/draft-07/schema#",
      "type": "object",
      "properties": {
        "service-fee-rate": { "type": "number", "minimum": 0, "maximum": 0.1 },
        "max-investment-per-user": { "type": "number", "minimum": 1000 }
      }
    })
  }

  tags = var.common_tags
}

# Hosted Configuration（实际的配置内容）
resource "aws_appconfig_hosted_configuration_version" "main" {
  application_id           = aws_appconfig_application.main.id
  configuration_profile_id = aws_appconfig_configuration_profile.main.id
  description              = "初始配置版本 v1.0"

  content = jsonencode({
    "service-fee-rate"       : 0.015,
    "max-investment-per-user": 500000,
    "supported-currencies"   : ["USD", "HKD", "SGD", "CNY"],
    "feature-toggles": {
      "enable-auto-invest"    : false,
      "enable-dark-mode"      : true,
      "enable-new-portfolio-ui": false,
    }
  })

  content_type = "application/json"
}

# 部署策略：配置如何逐步部署到目标
resource "aws_appconfig_deployment_strategy" "canary" {
  name                           = "Canary-10-30-100"
  description                    = "10% -> 30% -> 100% 金丝雀部署"
  deployment_duration_in_minutes = 10        # 每个阶段持续 10 分钟
  growth_factor                  = 3          # 每阶段扩大到 3 倍（10→30→100）
  replicate_to                   = "NONE"
  final_bake_time_in_minutes     = 5          # 全部部署后稳定 5 分钟
}

# CloudWatch 告警：配置变更后错误率超过 5% 自动回滚
resource "aws_cloudwatch_metric_alarm" "config_rollback" {
  alarm_name          = "${var.project_name}-${var.environment}-config-error-rollback"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/AppConfig"
  period              = 60
  statistic           = "Average"
  threshold           = 5
  alarm_description   = "AppConfig 配置变更后错误率超过 5%，触发自动回滚"
}

resource "aws_iam_role" "appconfig_monitor" {
  name = "${var.project_name}-${var.environment}-appconfig-monitor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "appconfig.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}
