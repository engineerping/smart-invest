variable "aws_region" {
  description = "AWS 主部署区域"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "项目名称前缀"
  type        = string
  default     = "smart-invest"
}

variable "ec2_instance_type" {
  description = "EC2 实例类型"
  type        = string
  default     = "t3.micro"
}

variable "ec2_ami" {
  description = "EC2 AMI ID（新加坡区域）"
  type        = string
  default     = "ami-02289b3fe036fe5cd"
}

variable "ec2_key_pair" {
  description = "EC2 Key Pair 名称"
  type        = string
  default     = "smart-invest-ec2-keypair"
}

variable "s3_bucket_name" {
  description = "前端静态资源 S3 Bucket 名称"
  type        = string
  default     = "smart-invest-frontend-service-prod-bucket-name"
}

variable "ebs_volume_size" {
  description = "EC2 根磁盘大小（GB）"
  type        = number
  default     = 8
}
