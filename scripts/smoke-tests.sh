#!/bin/bash

# Smoke tests for deployed application
# Quick validation that critical functionality works

SERVER=${1:-localhost}

echo "💨 Running smoke tests against ${SERVER}..."

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

FAILED=0

# Test 1: Health endpoint
echo "🏥 Testing health endpoint..."
if curl -sf "http://${SERVER}:8000/health" > /dev/null; then
    echo -e "${GREEN}✓ Health check passed${NC}"
else
    echo -e "${RED}✗ Health check failed${NC}"
    FAILED=$((FAILED + 1))
fi

# Test 2: API endpoint
echo "🔌 Testing API endpoint..."
RESPONSE=$(curl -sf "http://${SERVER}:8000/api/status")
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ API endpoint accessible${NC}"
else
    echo -e "${RED}✗ API endpoint failed${NC}"
    FAILED=$((FAILED + 1))
fi

# Test 3: Response time
echo "⏱️  Testing response time..."
RESPONSE_TIME=$(curl -o /dev/null -s -w '%{time_total}' "http://${SERVER}:8000/")
if (( $(echo "$RESPONSE_TIME < 2.0" | bc -l) )); then
    echo -e "${GREEN}✓ Response time OK (${RESPONSE_TIME}s)${NC}"
else
    echo -e "${RED}✗ Response time slow (${RESPONSE_TIME}s)${NC}"
    FAILED=$((FAILED + 1))
fi

# Summary
echo ""
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All smoke tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ ${FAILED} smoke test(s) failed${NC}"
    exit 1
fi
