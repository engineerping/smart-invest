#!/usr/bin/env bash
set -e

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"
BUCKET="smart-invest-artifacts-${ACCOUNT_ID}"
FRONTEND_BUCKET=$(cd infrastructure && terraform output -raw frontend_bucket)
EC2_IP=$(cd infrastructure && terraform output -raw ec2_public_ip)
CF_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?Comment=='smart-invest'][0].Id" --output text)

echo "=== Smart Invest Deployment ==="
echo "Account: $ACCOUNT_ID"
echo "Region: $REGION"
echo "Backend JAR S3: $BUCKET"
echo "Frontend Bucket: $FRONTEND_BUCKET"
echo "EC2 IP: $EC2_IP"

# Build backend
echo "[1/5] Building backend..."
cd backend
mvn clean package -DskipTests -q
cd ..

# Upload JAR
echo "[2/5] Uploading JAR to S3..."
aws s3 cp backend/app/target/smart-invest-app.jar "s3://${BUCKET}/smart-invest-app.jar"

# Deploy frontend
echo "[3/5] Building and deploying frontend..."
VITE_API_BASE_URL="https://${EC2_IP}" npm run build --prefix frontend
aws s3 sync frontend/dist/ "s3://${FRONTEND_BUCKET}/" --delete \
  --cache-control "public, max-age=31536000, immutable"
aws s3 cp frontend/dist/index.html "s3://${FRONTEND_BUCKET}/index.html" \
  --cache-control "no-cache"

echo "[4/5] Invalidating CloudFront..."
aws cloudfront create-invalidation --distribution-id "${CF_ID}" --paths "/*"

echo "[5/5] Restarting backend service..."
aws ssm send-command \
  --instance-ids "$(cd infrastructure && terraform output -raw instance_id)" \
  --document-name "AWS-RunShellScript" \
  --parameters commands='[
    "aws s3 cp s3://'"${BUCKET}"'/smart-invest-app.jar /opt/smart-invest/app.jar",
    "sudo systemctl restart smart-invest",
    "sleep 15",
    "sudo systemctl is-active smart-invest"
  ]'

echo "=== Deployment complete ==="
echo "Frontend: https://$(cd infrastructure && terraform output -raw cloudfront_domain)"
echo "Backend: https://${EC2_IP}"