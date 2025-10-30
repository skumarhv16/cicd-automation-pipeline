#!/bin/bash

# Deployment script for CI/CD pipeline
# Deploys application to specified environment

set -e

ENVIRONMENT=${1:-development}
BUILD_NUMBER=${2:-latest}

echo "🚀 Starting deployment to ${ENVIRONMENT}..."

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Load environment-specific configuration
CONFIG_FILE="config/${ENVIRONMENT}.env"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    echo -e "${GREEN}✓ Configuration loaded${NC}"
else
    echo -e "${RED}✗ Configuration file not found: ${CONFIG_FILE}${NC}"
    exit 1
fi

# Pre-deployment checks
echo "🔍 Running pre-deployment checks..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}✗ Docker is not running${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker is running${NC}"

# Check if image exists
IMAGE_NAME="sandeep/my-app:${BUILD_NUMBER}"
if ! docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
    echo "📥 Pulling image from registry..."
    docker pull "$IMAGE_NAME"
fi
echo -e "${GREEN}✓ Image available${NC}"

# Create backup of current deployment
echo "💾 Creating backup..."
BACKUP_NAME="backup-$(date +%Y%m%d-%H%M%S)"
docker tag sandeep/my-app:current "sandeep/my-app:${BACKUP_NAME}" 2>/dev/null || true
echo -e "${GREEN}✓ Backup created${NC}"

# Stop current containers
echo "🛑 Stopping current containers..."
docker-compose -f docker-compose.yml down --remove-orphans
echo -e "${GREEN}✓ Containers stopped${NC}"

# Deploy new version
echo "🚀 Deploying new version..."
export BUILD_NUMBER
export ENVIRONMENT
docker-compose -f docker-compose.yml up -d

# Wait for services to be healthy
echo "⏳ Waiting for services to be healthy..."
RETRY_COUNT=0
MAX_RETRIES=30

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker-compose ps | grep -q "healthy"; then
        echo -e "${GREEN}✓ Services are healthy${NC}"
        break
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Waiting... (${RETRY_COUNT}/${MAX_RETRIES})"
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}✗ Services failed to become healthy${NC}"
    echo "🔄 Rolling back..."
    ./scripts/rollback.sh "$ENVIRONMENT" "$BACKUP_NAME"
    exit 1
fi

# Tag successful deployment
docker tag "$IMAGE_NAME" "sandeep/my-app:current"

# Generate deployment report
cat > "deployment-report-${ENVIRONMENT}.txt" << EOF
Deployment Report
=================
Environment: ${ENVIRONMENT}
Build Number: ${BUILD_NUMBER}
Deployment Time: $(date '+%Y-%m-%d %H:%M:%S')
Status: SUCCESS
Image: ${IMAGE_NAME}
Backup: ${BACKUP_NAME}
EOF

echo ""
echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
echo "Environment: ${ENVIRONMENT}"
echo "Build: ${BUILD_NUMBER}"

exit 0
