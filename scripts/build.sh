#!/bin/bash

# Build script for CI/CD pipeline
# Compiles and packages the application

set -e  # Exit on error

echo "🔨 Starting build process..."

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Build timestamp
BUILD_TIME=$(date '+%Y-%m-%d %H:%M:%S')
echo "Build time: $BUILD_TIME"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf build/ dist/ *.egg-info
echo -e "${GREEN}✓ Cleanup complete${NC}"

# Install dependencies
echo "📦 Installing dependencies..."
if [ -f "requirements.txt" ]; then
    pip install -q -r requirements.txt
    echo -e "${GREEN}✓ Dependencies installed${NC}"
else
    echo -e "${RED}✗ requirements.txt not found${NC}"
    exit 1
fi

# Run linting
echo "🔍 Running code linting..."
if command -v pylint &> /dev/null; then
    pylint src/ --exit-zero
    echo -e "${GREEN}✓ Linting complete${NC}"
else
    echo "⚠️  pylint not found, skipping..."
fi

# Check code formatting
echo "📝 Checking code formatting..."
if command -v black &> /dev/null; then
    black --check src/ || true
    echo -e "${GREEN}✓ Format check complete${NC}"
else
    echo "⚠️  black not found, skipping..."
fi

# Build package
echo "📦 Building package..."
if [ -f "setup.py" ]; then
    python setup.py build
    echo -e "${GREEN}✓ Package built successfully${NC}"
fi

# Create version file
echo "📝 Creating version file..."
cat > src/version.py << EOF
# Auto-generated version file
__version__ = "${BUILD_NUMBER:-dev}"
__build_time__ = "${BUILD_TIME}"
__git_commit__ = "$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
EOF
echo -e "${GREEN}✓ Version file created${NC}"

# Generate build report
echo "📊 Generating build report..."
cat > build-report.txt << EOF
Build Report
============
Build Number: ${BUILD_NUMBER:-dev}
Build Time: ${BUILD_TIME}
Git Commit: $(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')
Python Version: $(python --version)
EOF
echo -e "${GREEN}✓ Build report generated${NC}"

echo ""
echo -e "${GREEN}✅ Build completed successfully!${NC}"
exit 0
