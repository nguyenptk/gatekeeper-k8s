#!/bin/bash

curl http://localhost:8060
echo

for i in {1..10}; do
  echo "==============================================="
  echo "> Calling /login endpoint to get the JWT Token."
  TOKEN=$(curl -s -X POST http://localhost:8060/login \
    -H "Content-Type: application/json" \
    -d '{"username":"user", "password":"password"}' | jq -r '.token')

  echo "JWT Token: $TOKEN"
  echo

  echo "==================================="
  echo "> Calling /public endpoint (no token)"
  curl -i -X GET http://localhost:8060/public
  echo

  echo "======================================"
  echo "> Calling /private endpoint (no token)"
  curl -i -X GET http://localhost:8060/private
  echo

  echo "========================================"
  echo "> Calling /private endpoint (with token)"
  curl -i -X GET http://localhost:8060/private -H "Authorization: Bearer $TOKEN"
  printf "\n"
done