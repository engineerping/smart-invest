# ==============================================================================
# CDN 模块 —— Terraform & Provider 版本约束
# ==============================================================================
#
# 这个文件告诉 Terraform 三件事：
#   1. 这个模块最低需要哪个版本的 Terraform 核心
#   2. 这个模块依赖哪些 Provider（以及版本范围）
#   3. 这个模块期望调用方传入哪些 Provider（configuration_aliases）
#
# ═══════════════════════════════════════════════════════════════════════════════
# 为什么子模块也需要 versions.tf？
# ═══════════════════════════════════════════════════════════════════════════════
#
# Terraform 的子模块默认"继承"根模块的 provider 配置。
# 但如果子模块使用了 alias provider（比如 aws.us_east_1），
# 就必须在这里声明 configuration_aliases，否则根模块传进来的 provider 会被当作
# "未定义"（就是 terraform init 那个 Warning 的来源）。
#
# 类比：
#   - 根模块的 required_providers = 餐厅菜单（声明有哪些菜）
#   - 子模块的 configuration_aliases = 客人点菜（声明我需要什么）
#   - 如果客人不说需要什么，厨房也能上菜（Terraform 会猜），
#     但会警告你"你不说我怎么知道你要的是这个"
# ═══════════════════════════════════════════════════════════════════════════════

terraform {

  # ─── Terraform 核心版本要求 ───
  # 这个模块需要 Terraform >= 1.0（1.x 都有完善的模块 system）。
  # 不需要和根模块一样严格，因为模块本身没有用到版本相关的高级特性。
  required_version = ">= 1.0"

  # ═══════════════════════════════════════════════════════════════════════════
  # required_providers —— 模块依赖的 Provider 声明
  # ═══════════════════════════════════════════════════════════════════════════
  #
  # 每个 provider 条目包含三个字段：
  #
  #   source  —— "谁发布的这个 Provider"
  #             格式：<组织名>/<Provider名>
  #             类比 Maven 的 groupId/artifactId。
  #             HashiCorp 官方的 AWS Provider 就是 "hashicorp/aws"。
  #
  #   version —— "接受哪个版本范围"
  #             ~> 5.0 = 悲观约束（pessimistic constraint）
  #             意思是：>= 5.0.0 且 < 6.0.0
  #             只接受 5.x 的所有小版本，不升级到 6.x（可能有 Breaking Changes）。
  #             这是 Terraform 推荐的版本锁定方式。
  #
  #   configuration_aliases —— "我不自己创建这个 provider，但会从调用方接收它"
  #             这是理解本文件的关键！
  #             ═══════════════════════════════════════════════════════════
  #             默认情况下，一个模块只需要一个 provider 实例。
  #             比如 networking 模块只需要一个 aws provider（在 ap-southeast-1 操作），
  #             那么它什么都不用声明——Terraform 会自动把根模块的 aws 传进来。
  #
  #             但 CDN 模块不一样！CloudFront 需要 us-east-1，WAF 也需要 us-east-1。
  #             这意味着 CDN 模块需要 TWO 个 aws provider：
  #               - aws           → ap-southeast-1（S3 存储桶）
  #               - aws.us_east_1 → us-east-1（CloudFront WAF）
  #
  #             configuration_aliases 就是"预告"调用方：
  #             「嘿，我内部会用到 aws.us_east_1 这个别名 provider，
  #               你得在调用我的时候通过 providers 元参数传给我！」
  #             ═══════════════════════════════════════════════════════════
  #
  #             如果缺少这个声明，Terraform 会报 Warning：
  #               "There is no explicit declaration for local provider name
  #                'aws.us_east_1' in module.cdn, so Terraform is assuming
  #                you mean to pass a configuration for 'hashicorp/aws'."
  #
  #             直译：我没在你模块里找到 aws.us_east_1 的声明，
  #             但我猜你是想传一个 hashicorp/aws 的 provider —— 我帮你干活，但你最好明说。
  # ═══════════════════════════════════════════════════════════════════════════
  required_providers {

    # ─── AWS Provider ───
    # 这里只有一个 aws 条目，但通过 configuration_aliases 宣告了两个身份：
    #
    #   【身份 1】aws（默认，无形参）
    #     由根模块自动传入（因为根模块也声明了 hashicorp/aws）。
    #     CDN 模块里不写 provider = ... 的所有 aws_* 资源（如 aws_s3_bucket）
    #     都走这个默认 provider，region = ap-southeast-1。
    #
    #   【身份 2】aws.us_east_1（带别名，需要显式传入）
    #     由根模块通过 providers 元参数显式传入。
    #     CDN 模块里写了 provider = aws.us_east_1 的资源（如 aws_wafv2_web_acl）
    #     走这个 provider，region = us-east-1。
    #
    #   ═══════════════════════════════════════════════════════════════════
    #   完整的数据流：
    #
    #   【根模块 main.tf】                      【CDN 模块 main.tf】
    #   ┌─────────────────────────┐            ┌──────────────────────────────┐
    #   │ provider "aws" {        │            │ resource "aws_s3_bucket" {}   │
    #   │   alias  = "us_east_1"  │─── 传入 ──▶│   # 走默认 provider（无形参）  │
    #   │   region = "us-east-1"  │            │                              │
    #   │ }                       │            │ resource "aws_wafv2_web_acl" {│
    #   │                         │            │   provider = aws.us_east_1    │
    #   │ module "cdn" {          │            │   # 走 US East 这个 provider   │
    #   │   providers = {         │            │ }                            │
    #   │     aws.us_east_1 = ────┼── 传入 ──▶│                              │
    #   │       aws.us_east_1     │            │                              │
    #   │   }                     │            │                              │
    #   │ }                       │            │                              │
    #   └─────────────────────────┘            └──────────────────────────────┘
    #
    #   注意：根模块的默认 aws provider 是自动传入的，不需要在 providers 里写。
    #   只有带 alias 的 provider 才需要显式传入。
    #   ═══════════════════════════════════════════════════════════════════
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"

      # ⚠️ 注意：方括号里的 aws.us_east_1 不能加引号！
      # 这里需要的是 Terraform 的 provider 引用（裸标识符），不是字符串。
      # [aws.us_east_1]   = provider 引用，Terraform 能识别
      # ["aws.us_east_1"] = 字符串字面量，Terraform 报错（就是你刚看到的那个 Error）
      # 如果有多个 alias provider 也从外部传入，都写在这个列表里：
      #   configuration_aliases = [aws.us_east_1, aws.us_west_2, aws.eu_central_1]
      configuration_aliases = [aws.us_east_1]
    }
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# 总结：根模块 vs 子模块的 Provider 关系
# ═══════════════════════════════════════════════════════════════════════════════
#
#   角色         │ 负责什么                │ 例子
#  ──────────────┼─────────────────────────┼──────────────────────────────────
#   根模块       │ 1. 创建 provider 实例   │ provider "aws" { alias = "us_east_1" ... }
#  （调用方）    │ 2. 传入给子模块         │ module "cdn" { providers = {...} }
#  ──────────────┼─────────────────────────┼──────────────────────────────────
#   子模块       │ 1. 声明需要什么版本     │ version = "~> 5.0"
#  （被调用方）  │ 2. 声明接收哪些别名     │ configuration_aliases = ["aws.us_east_1"]
#               │ 3. 在 resource 里使用     │ provider = aws.us_east_1
#  ═══════════════════════════════════════════════════════════════════════════
#
# 类比：函数参数的声明与传递
#
#   根模块 = 调用方（传实参）
#   module "cdn" {
#     providers = {
#       aws.us_east_1 = aws.us_east_1    ← 实参：把我定义好的 provider 实例传进去
#     }
#   }
#
#   子模块 = 函数签名（声明形参）
#   required_providers {
#     aws = {
#       configuration_aliases = [aws.us_east_1]   ← 形参：我会接收一个叫 us_east_1 的 provider
#     }
#   }
# ═══════════════════════════════════════════════════════════════════════════
