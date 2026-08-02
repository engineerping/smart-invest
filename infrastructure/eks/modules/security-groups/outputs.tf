output "eks_cluster_sg_id" { value = aws_security_group.eks_cluster.id }
output "eks_node_sg_id" { value = aws_security_group.eks_node.id }
output "bastion_sg_id" { value = aws_security_group.bastion.id }
output "aurora_sg_id" { value = aws_security_group.aurora.id }
output "elasticache_sg_id" { value = aws_security_group.elasticache.id }
output "documentdb_sg_id" { value = aws_security_group.documentdb.id }
output "mq_sg_id" { value = aws_security_group.mq.id }
output "alb_sg_id" { value = aws_security_group.alb.id }
