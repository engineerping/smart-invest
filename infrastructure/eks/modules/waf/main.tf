# =============================================================================
# AWS WAF 模块 - Web 应用防火墙
# =============================================================================
# AWS WAF 是应用层的 Web 防火墙，用于保护 Web 应用免受常见攻击
# WAF 部署在 CloudFront 或 ALB 前面，拦截恶意流量
#
# 防御的常见攻击：
#   1. SQL 注入（SQL Injection）
#   2. 跨站脚本攻击（XSS）
#   3. DDoS 攻击（配合 AWS Shield）
#   4. 恶意爬虫和扫描器
#   5. IP 黑白名单
#
# 注意：WAF 是全局服务，通过 CloudFront 使用

resource "aws_wafv2_web_acl" "main" {
  name        = "${var.project_name}-${var.environment}-web-acl"
  description = "Smart Invest WAF - ${var.environment} 环境"
  scope       = "CLOUDFRONT"  # 作用在 CloudFront 上

  # --- 默认行为：允许（白名单模式）---
  default_action {
    allow {}
  }

  # --- 规则 1：AWS 托管 的核心规则组 ---
  # AWS 管理的规则集合，自动更新以应对最新威胁
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}  # 使用规则组的默认动作（Block）
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true  # 采样请求用于调试
    }
  }

  # --- 规则 2：SQL 注入防护 ---
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesSQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # --- 规则 3：IP 速率限制（防止 DDoS）---
  # 同一个 IP 在 5 分钟内超过 2000 次请求则触发
  rule {
    name     = "RateLimit"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimit"
      sampled_requests_enabled   = true
    }
  }

  # --- 规则 4：IP 黑名单（管理员可以手动添加恶意 IP）---
  rule {
    name     = "IPBlacklist"
    priority = 4

    action {
      block {}
    }

    # 默认黑名单为空，通过 ip_set 管理
    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.blacklist.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "IPBlacklist"
      sampled_requests_enabled   = true
    }
  }

  # --- 可见性配置 ---
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.environment}-waf"
    sampled_requests_enabled   = true
  }

  tags = var.common_tags
}

# WAF IP Set：黑名单 IP 集合
resource "aws_wafv2_ip_set" "blacklist" {
  name               = "${var.project_name}-${var.environment}-blacklist"
  description        = "被阻止的恶意 IP 列表"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  # 初始为空，由安全运营人员通过 AWS Console 或 API 维护
  addresses = []

  tags = var.common_tags
}
