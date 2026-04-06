#!/bin/bash
set -e
yum update -y
yum install -y java-21-amazon-corretto-headless nginx

mkdir -p /opt/smart-invest
aws s3 cp ${app_jar_s3} /opt/smart-invest/app.jar

DB_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id ${db_secret_arn} --region ${aws_region} \
  --query SecretString --output text)

DB_URL=$(echo $DB_SECRET | python3 -c \
  "import json,sys; s=json.load(sys.stdin); print(f\"jdbc:postgresql://{s['host']}:{s['port']}/{s['dbname']}\")")
DB_USER=$(echo $DB_SECRET | python3 -c "import json,sys; s=json.load(sys.stdin); print(s['username'])")
DB_PASS=$(echo $DB_SECRET | python3 -c "import json,sys; s=json.load(sys.stdin); print(s['password'])")

cat > /etc/systemd/system/smart-invest.service <<EOF
[Unit]
Description=Smart Invest Application
After=network.target

[Service]
Type=simple
User=ec2-user
Environment="SPRING_DATASOURCE_URL=$DB_URL"
Environment="SPRING_DATASOURCE_USERNAME=$DB_USER"
Environment="SPRING_DATASOURCE_PASSWORD=$DB_PASS"
Environment="AWS_REGION=${aws_region}"
Environment="SPRING_PROFILES_ACTIVE=prod"
ExecStart=/usr/bin/java -Xms256m -Xmx768m -jar /opt/smart-invest/app.jar
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/nginx/conf.d/smart-invest.conf <<'NGINX'
server {
    listen 443 ssl;
    server_name _;
    location /api/ {
        proxy_pass       http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX

systemctl daemon-reload
systemctl enable smart-invest nginx
systemctl start smart-invest nginx
