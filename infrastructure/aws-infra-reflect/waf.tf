# ============================================================================
# WAF (Web Application Firewall) — Web 应用防火墙
# ============================================================================
#
# 一句话理解：
#   WAF 就是站你网站门口的一个"安检门"，所有流量必须经过它检查才放行。
#   它能识别并拦截 SQL 注入、XSS 攻击、恶意 IP、机器人等常见 Web 攻击。
#
# ============================================================================
#
# 架构：WAF 在整个系统中的位置
#
#   用户浏览器
#       │
#       ▼
#   CloudFront（CDN，全球分发）
#       │
#       ▼
#   WAF（本文件定义） ← 安检门，在此检查每个请求是否恶意
#       │
#       ▼
#   后端服务器（EC2 / ALB）
#
#   流量走向：用户 → CloudFront → WAF 检查 → 通过 OR 拦截 → 后端
#
# ============================================================================
#
# 关键概念：scope = "CLOUDFRONT" 意味着什么
#
#   WAF 有两种部署模式：
#   ┌───────────────┬─────────────────────────────────────┐
#   │ CLOUDFRONT    │ 挂在 CloudFront 上，全球生效         │
#   │ REGIONAL      │ 挂在 ALB/API Gateway 上，单个区域    │
#   └───────────────┴─────────────────────────────────────┘
#
#   本项目用的是 CLOUDFRONT 模式，且这个资源必须部署在 us-east-1！
#   （AWS 的硬性规定，所以 main.tf 中有一个专门的 us_east_1 provider）
#
# ============================================================================
#
# 本 WAF 使用了 AWS 托管的三条规则组（Managed Rule Groups）：
#
#   ┌──────────────────────────────────────┬──────────────────────────────┐
#   │ 规则组                               │ 作用                         │
#   ├──────────────────────────────────────┼──────────────────────────────┤
#   │ AmazonIPReputationList               │ 拦截已知的恶意 IP（垃圾邮件、 │
#   │                                      │ 僵尸网络等）                  │
#   ├──────────────────────────────────────┼──────────────────────────────┤
#   │ CommonRuleSet (CRS)                  │ 防护 OWASP Top 10 常见漏洞：  │
#   │                                      │ SQL 注入、XSS、命令注入等     │
#   ├──────────────────────────────────────┼──────────────────────────────┤
#   │ KnownBadInputsRuleSet                │ 拦截已知的攻击载荷模式（恶意  │
#   │                                      │ 路径遍历、特殊字符攻击等）    │
#   └──────────────────────────────────────┴──────────────────────────────┘
#
#   这些是 AWS 官方维护的规则，自动更新，不用自己写正则。
#
# ============================================================================
#
# 关于 action 的说明：
#
#   default_action { allow {} }  ← 默认：没匹配到规则 → 放行
#   override_action { none {} }  ← 匹配到规则 → 执行规则默认动作（通常是拦截）
#
#   流程：请求进来 → 逐条匹配规则 → 命中 → 拦截 / 没命中 → 放行
#
#   override_action 的可选值：
#   - none {}     — 执行规则组定义的默认动作（拦截）
#   - count {}    — 不拦截，只记录日志（适合调试、灰度观察）
#   - block {}    — 强制拦截
#
#   如果新规则上线后误杀了正常流量，可以临时改为 count {} 观察，再决定是否放行。
#
# ============================================================================

resource "aws_wafv2_web_acl" "cloudfront_waf" {
  # WAF 必须在 us-east-1 创建（CloudFront 的硬性要求）
  provider    = aws.us_east_1

  # WAF 名称，以项目名作为前缀方便识别
  name        = "${var.project_name}-waf"

  # CloudFront 模式，表示这个 WAF 是全球生效的
  scope       = "CLOUDFRONT"

  description = "WAF for ${var.project_name} CloudFront distribution"

  # =========================================================================
  # 默认动作：没命中任何规则时 — 放行
  # =========================================================================
  default_action {
    allow {}
  }

  # =========================================================================
  # 规则 1：Amazon IP 声誉列表
  # 自动拦截已知恶意 IP（由 AWS 威胁研究团队维护，自动更新）
  # =========================================================================
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 0

    # none = 不覆盖，执行规则组默认行为（即拦截）
    override_action { none {} }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesAmazonIpReputationList"
      sampled_requests_enabled   = true  # 开启采样，可在 WAF 控制台查看拦截的请求样本
    }
  }

  # =========================================================================
  # 规则 2：通用规则集（OWASP Top 10 防护）
  # 防护：SQL 注入、跨站脚本(XSS)、本地文件包含、HTTP 协议违规等
  # =========================================================================
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action { none {} }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # =========================================================================
  # 规则 3：已知恶意输入规则集
  # 检测请求中可能包含的恶意 Payload（路径遍历、特殊编码攻击等）
  # =========================================================================
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action { none {} }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # =========================================================================
  # 全局可见性配置
  # CloudWatch 可以查看 WAF 指标（拦截数、放行数）
  # =========================================================================
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name    = "${var.project_name}-waf"
    Project = var.project_name
  }
}
