# =============================================================================
# Amazon MQ 消息队列模块
# =============================================================================
# Amazon MQ 是 AWS 托管 的 Apache ActiveMQ 消息队列
# 为什么选择 Amazon MQ 而不是 Amazon SQS/SNS：
#   1. ActiveMQ 支持 AMQP/JMS 标准协议（银行系统常用 JMS）
#   2. Java 生态可以直接用 JMS API，不需要改代码
#   3. 支持事务性消息、持久化消息、死信队列（DLQ）
#
# 在本项目中的用途：
#   - 订单服务 → 通知服务：用户下单后异步发送确认通知
#   - 基金交易 → 外部交易系统：异步发送交易指令

resource "aws_mq_broker" "main" {
  broker_name = "${var.project_name}-${var.environment}-mq"

  engine_type         = "ActiveMQ"
  engine_version      = "5.17.6"       # ActiveMQ 5.17 LTS 版本
  host_instance_type  = var.environment == "prd" ? "mq.m5.large" : "mq.t3.micro"
  deployment_mode     = var.environment == "prd" ? "ACTIVE_STANDBY_MULTI_AZ" : "SINGLE_INSTANCE"

  # 公网不可访问，只用 VPC 内部通信
  publicly_accessible = false

  # 用户配置
  user {
    username = "smartinvest"
    password = random_password.mq.result
  }

  # 安全组配置
  security_groups = var.allowed_security_group_ids
  subnet_ids      = [var.subnet_ids[0]]  # ActiveMQ 只需要一个子网（或由 AWS 自动处理 Multi-AZ）

  # 加密配置
  encryption_options {
    kms_key_id        = var.kms_key_arn
    use_aws_owned_key = false  # 使用我们自己管理的 KMS 密钥
  }

  # 日志配置
  logs {
    general = true   # 记录一般日志（连接/断开等）
    audit   = true   # 记录审计日志（谁发了什么消息）
  }

  # 维护窗口
  maintenance_window_start_time {
    day_of_week = "SUNDAY"
    time_of_day = "04:00"  # UTC 凌晨 4 点
    time_zone   = "UTC"
  }

  tags = var.common_tags
}

# MQ 配置
resource "aws_mq_configuration" "main" {
  name           = "${var.project_name}-${var.environment}-mq-config"
  engine_type    = "ActiveMQ"
  engine_version = "5.17.6"

  # ActiveMQ 的 XML 配置
  data = <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <broker xmlns="http://activemq.apache.org/schema/core">
      <!-- 持久化适配器：消息写入 KahaDB 硬盘存储，防止丢失 -->
      <persistenceAdapter>
        <kahaDB directory="/opt/amq/data/kahadb"/>
      </persistenceAdapter>

      <!-- 传输连接器：OpenWire 协议（JMS 默认协议）-->
      <transportConnectors>
        <transportConnector name="openwire" uri="ssl://0.0.0.0:61617?maximumConnections=1000"/>
      </transportConnectors>
    </broker>
  XML
}

resource "random_password" "mq" {
  length  = 16
  special = false
}
