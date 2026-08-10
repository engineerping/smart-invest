# =============================================================================
# RDS 模块输出变量
# =============================================================================

# -------------------------------------------------------------------
# db_secret_arn: 数据库密码在 AWS Secrets Manager 中的 ARN
#
# ARN（Amazon Resource Name）是 AWS 资源的唯一标识符。
# 格式：arn:aws:secretsmanager:<region>:<account_id>:secret:<secret_name>-<random>
#
# EC2 通过这个 ARN 从 Secrets Manager 获取数据库密码。
# 在 UserData 脚本中使用 AWS CLI：
#   aws secretsmanager get-secret-value --secret-id <arn> --region <region>
#
# manage_master_user_password = true 创建的 Secret 包含以下字段：
#   - username: 数据库用户名
#   - password: 数据库密码
#   - engine: postgres
#   - host: 数据库终端节点
#   - port: 5432
#   - dbname: smartinvest
# -------------------------------------------------------------------
output "db_secret_arn" { value = aws_db_instance.postgres.master_user_secret[0].secret_arn }

# -------------------------------------------------------------------
# db_endpoint: 数据库连接端点
#
# 格式：<identifier>.<random>.<region>.rds.amazonaws.com:5432
# 例如：smart-invest-db.abc123.us-east-1.rds.amazonaws.com:5432
#
# 端点是一个 DNS 名称，AWS 自动解析到 RDS 实例的私有 IP。
# RDS 内部 IP 可能会变（维护、故障切换），但端点名称永远不变。
# 应用应该用端点而不是 IP 连接数据库。
# -------------------------------------------------------------------
output "db_endpoint"    { value = aws_db_instance.postgres.endpoint }
