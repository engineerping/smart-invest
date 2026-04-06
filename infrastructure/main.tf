module "vpc" {
  source     = "./modules/vpc"
  region     = var.aws_region
  admin_cidr = var.admin_cidr
}

module "iam" {
  source = "./modules/iam"
}

module "rds" {
  source     = "./modules/rds"
  subnet_ids = [module.vpc.public_subnet_id, module.vpc.private_subnet_id]
  rds_sg_id  = module.vpc.rds_sg_id
}

module "ec2" {
  source                = "./modules/ec2"
  public_subnet_id      = module.vpc.public_subnet_id
  ec2_sg_id             = module.vpc.ec2_sg_id
  instance_profile_name  = module.iam.instance_profile_name
  key_pair_name         = var.key_pair_name
  db_secret_arn         = module.rds.db_secret_arn
  region                = var.aws_region
  app_jar_s3_path       = "s3://smart-invest-artifacts-${var.account_id}/smart-invest-app.jar"
}

module "s3_cloudfront" {
  source     = "./modules/s3-cloudfront"
  account_id = var.account_id
}
