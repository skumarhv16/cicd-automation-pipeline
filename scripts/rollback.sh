#!/bin/bash

# Rollback script for CI/CD pipeline
# Reverts to previous version in case of deployment failure

set -e

ENVIRONMENT=${1:-development}
VERSION=${2:-latest}

echo "🔄 Starting rollback to version ${VERSION}..."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Confirmation for production
if [ "$ENVIRONMENT" = "production" ]; then
    echo -e "${YELLOW}⚠️  WARNING: Rolling back PRODUCTION environment${NC}"
    read -p "Are you sure? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Rollback cancelled"
        exit 0
    fi
fi

# Stop current containers
echo "🛑 Stopping current containers..."
docker-compose down

# Rollback to previous version
echo "⏮️  Rolling back to ${VERSION}..."
IMAGE_NAME="sandeep/my-app:${VERSION}"

if ! docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
    echo -e "${RED}✗ Version ${VERSION} not found${NC}"
    exit 1
fi

# Update docker-compose to use rollback version
export BUILD_NUMBER=$VERSION
export ENVIRONMENT

# Start with previous version
docker-compose up -d

# Wait for health check
echo "⏳ Waiting for services..."
sleep 10

if docker-compose ps | grep -q "healthy"; then
    echo -e "${GREEN}✓ Rollback successful${NC}"
    
    # Log rollback
    cat >> rollback-log.txt << EOF
[$(date '+%Y-%m-%d %H:%M:%S')] Rolled back ${ENVIRONMENT} to ${VERSION}
EOF
    
    exit 0
else
    echo -e "${RED}✗ Rollback failed${NC}"
    exit 1
fi
