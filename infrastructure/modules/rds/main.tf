resource "aws_db_subnet_group" "main" {
  name       = "smart-invest-db-sng"
  subnet_ids = var.subnet_ids
}

resource "aws_db_instance" "postgres" {
  identifier = "smart-invest-db"
  engine               = "postgres"
  engine_version       = "16.3"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  storage_type         = "gp2"
  db_name              = "smartinvest"
  username             = "smartadmin"
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]

  backup_retention_period = 7
  multi_az               = false
  publicly_accessible     = false
  deletion_protection     = false
  skip_final_snapshot    = false
  final_snapshot_identifier = "smart-invest-final-snapshot"
}
