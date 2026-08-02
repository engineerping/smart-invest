output "cluster_id" { value = aws_rds_cluster.aurora.id }
output "cluster_endpoint" { value = aws_rds_cluster.aurora.endpoint }
output "reader_endpoint" { value = aws_rds_cluster.aurora.reader_endpoint }
output "cluster_port" { value = aws_rds_cluster.aurora.port }
output "master_password_secret" { value = random_password.aurora_master.result; sensitive = true }
