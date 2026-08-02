output "broker_endpoint" { value = aws_mq_broker.main.instances[0].endpoints[0] }
output "broker_id" { value = aws_mq_broker.main.id }
