#!/bin/bash

echo "Getting JWT..."
TOKEN=$(curl -s -X POST http://localhost:8060/login \
  -H "Content-Type: application/json" \
  -d '{"username":"user", "password":"password"}' | jq -r '.token')

echo "Token: $TOKEN"
echo

echo "====================="
echo "✅ /public (no token)"
curl -i -X GET http://localhost:8060/public
echo

echo "====================="
echo "❌ /private (no token)"
curl -i -X GET http://localhost:8060/private
echo

echo "========================"
echo "✅ /private (with token)"
curl -i -X GET http://localhost:8060/private -H "Authorization: Bearer $TOKEN"
