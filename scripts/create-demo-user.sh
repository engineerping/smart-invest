#!/usr/bin/env bash
set -e
API="http://localhost:8080"

echo "Creating demo user..."
RESP=$(curl -s -X POST "${API}/api/auth/register" \
  -H 'Content-Type: application/json' \
  -d '{"email":"demo@smartinvest.example.com","password":"Demo1234!","fullName":"Demo User"}')
TOKEN=$(echo $RESP | python3 -c "import json,sys; print(json.load(sys.stdin)['accessToken'])")
echo "Demo user created. Token: ${TOKEN:0:20}..."

# Get a fund ID
FUND_ID=$(curl -s "${API}/api/funds?type=MONEY_MARKET" \
  -H "Authorization: Bearer $TOKEN" \
  | python3 -c "import json,sys; funds=json.load(sys.stdin); print(funds[0]['id'] if funds else '')")
echo "Fund ID: $FUND_ID"

# Place a demo order
curl -s -X POST "${API}/api/orders" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"fundId\":\"${FUND_ID}\",\"orderType\":\"ONE_TIME\",\"amount\":5000}" \
  | python3 -m json.tool
echo "Demo order placed."