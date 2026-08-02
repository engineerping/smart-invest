output "cluster_id" { value = aws_elasticache_replication_group.redis.id }
output "primary_endpoint" { value = aws_elasticache_replication_group.redis.primary_endpoint_address }

output "redis_auth_token" { value = random_password.redis.result; sensitive = true }

output "redis_connection_string" {
  value = "rediss://${aws_elasticache_replication_group.redis.primary_endpoint_address}:6379"
  description = "Redis 安全连接字符串（rediss = Redis over TLS）"
  sensitive = true
}
