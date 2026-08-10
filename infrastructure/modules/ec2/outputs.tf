# =============================================================================
# EC2 模块输出变量
# =============================================================================

# -------------------------------------------------------------------
# public_ip: 弹性公网 IP 地址
# 这是一个固定的公网 IPv4 地址，通过 EIP 资源绑定。
#
# 使用方式：
#   - SSH 登录: ssh ec2-user@<public_ip> -i <key_pair>.pem
#   - 应用访问: http://<public_ip>:8080 或 https://<public_ip>
#   - DNS 配置: 将域名 A 记录指向这个 IP
#
# 注意：这个 IP 在 EC2 停止后不会变（和默认公网 IP 不同）。
# -------------------------------------------------------------------
output "public_ip"   { value = aws_eip.app.public_ip }

# -------------------------------------------------------------------
# instance_id: EC2 实例 ID（如 i-0abcd123456789）
#
# 使用方式：
#   - Terraform 输出: terraform output instance_id
#   - AWS Console: 搜索此 ID 定位实例
#   - CloudWatch: 按 instance_id 维度查询监控指标
#   - AWS CLI: aws ec2 describe-instances --instance-ids <id>
# -------------------------------------------------------------------
output "instance_id" { value = aws_instance.app.id }
