data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.small"
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.ec2_sg_id]
  iam_instance_profile   = var.instance_profile_name
  key_name               = var.key_pair_name

  user_data = templatefile("${path.module}/user_data.sh", {
    db_secret_arn = var.db_secret_arn
    aws_region    = var.region
    app_jar_s3    = var.app_jar_s3_path
  })

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
}
  tags = { Name = "smart-invest-app" }
}

resource "aws_eip" "app" {
  instance = aws_instance.app.id
  domain   = "vpc"
}
