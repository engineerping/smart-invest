#!/usr/bin/env bash
set -e

REGION="us-east-1"
SNS_ARN=$(aws sns create-topic --name smart-invest-alerts \
  --query TopicArn --output text --region $REGION 2>/dev/null || \
  aws sns list-topics --query "Topics[?contains(TopicArn,'smart-invest-alerts')].TopicArn" --output text --region $REGION)

echo "SNS Topic ARN: $SNS_ARN"

# CloudWatch Log Group
aws logs create-log-group --log-group-name /smart-invest/application --region $REGION 2>/dev/null || echo "Log group already exists"

# EC2 ID
EC2_ID=$(cd infrastructure && terraform output -raw instance_id)

# Create Alarm: EC2 CPU Usage Exceeds 80% for 10 Consecutive Minutes
aws cloudwatch put-metric-alarm \
  --alarm-name "SmartInvest-CPU-High" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --dimensions Name=InstanceId,Value=${EC2_ID} \
  --statistic Average --period 300 --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --alarm-actions ${SNS_ARN} \
  --region $REGION

# Create Alarm: RDS Free Storage Space Below Threshold
aws cloudwatch put-metric-alarm \
  --alarm-name "SmartInvest-RDS-Storage-Low" \
  --metric-name FreeStorageSpace \
  --namespace AWS/RDS \
  --dimensions Name=DBInstanceIdentifier,Value=smart-invest-db \
  --statistic Average --period 300 --threshold 5368709120 \
  --comparison-operator LessThanThreshold \
  --evaluation-periods 1 \
  --alarm-actions ${SNS_ARN} \
  --region $REGION

# Create Alarm: More Than 10 5xx Errors Within 5 Minutes
aws cloudwatch put-metric-alarm \
  --alarm-name "SmartInvest-5xx-Rate" \
  --metric-name "5XXError" \
  --namespace "AWS/ApiGateway" \
  --statistic Sum \
  --period 300 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --alarm-actions $SNS_TOPIC_ARN \
  --region $REGION

echo "CloudWatch alarms created."