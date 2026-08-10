resource "aws_security_group" "smart_invest" {
  name        = "${var.project_name}-security-group"
  description = "Smart Invest backend security group"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "API port for CloudFront"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # ⚠️ 建议生产环境替换为您的固定 IP，例如：["203.0.113.0/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-security-group"
    Project = var.project_name
  }
}
