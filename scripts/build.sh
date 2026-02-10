#!/bin/bash

# California Plate Validator - Build Script
# Builds Docker image and pushes to ECR/DockerHub

set -e

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_message() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
PROJECT_NAME="california-plate-validator"
VERSION="1.0.0"
REGION=${AWS_DEFAULT_REGION:-"us-west-2"}
ENVIRONMENT=${ENVIRONMENT:-"development"}
DOCKERHUB_USERNAME=${DOCKERHUB_USERNAME:-"joebaho2"}

# Function to login to ECR
login_to_ecr() {
    print_message "Logging in to Amazon ECR..."
    
    if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        print_error "AWS credentials not found. Please set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
        exit 1
    fi
    
    # Get ECR registry URL
    ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
    ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
    
    # Login to ECR
    aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
    
    print_success "Logged in to ECR successfully"
}

# Function to login to DockerHub
login_to_dockerhub() {
    if [ -n "$DOCKERHUB_USERNAME" ] && [ -n "$DOCKERHUB_PASSWORD" ]; then
        print_message "Logging in to DockerHub..."
        echo "$DOCKERHUB_PASSWORD" | docker login --username $DOCKERHUB_USERNAME --password-stdin
        print_success "Logged in to DockerHub successfully"
    else
        print_message "DockerHub credentials not provided, skipping DockerHub login"
    fi
}

# Function to build Docker image
build_image() {
    print_message "Building Docker image..."
    
    # Build arguments
    BUILD_ARGS=""
    if [ -n "$ENVIRONMENT" ]; then
        BUILD_ARGS="$BUILD_ARGS --build-arg ENVIRONMENT=$ENVIRONMENT"
    fi
    
    # Build the image
    docker build $BUILD_ARGS \
        -t ${PROJECT_NAME}:${VERSION} \
        -t ${PROJECT_NAME}:latest \
        -f docker/Dockerfile .
    
    print_success "Docker image built successfully"
    
    # Tag for ECR
    ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
    ECR_REPO="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${PROJECT_NAME}-${ENVIRONMENT}"
    
    docker tag ${PROJECT_NAME}:latest ${ECR_REPO}:latest
    docker tag ${PROJECT_NAME}:${VERSION} ${ECR_REPO}:${VERSION}
    
    # Tag for DockerHub
    if [ -n "$DOCKERHUB_USERNAME" ]; then
        docker tag ${PROJECT_NAME}:latest ${DOCKERHUB_USERNAME}/${PROJECT_NAME}:latest
        docker tag ${PROJECT_NAME}:${VERSION} ${DOCKERHUB_USERNAME}/${PROJECT_NAME}:${VERSION}
    fi
    
    print_success "Docker images tagged successfully"
}

# Function to push to ECR
push_to_ecr() {
    print_message "Pushing images to ECR..."
    
    ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
    ECR_REPO="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${PROJECT_NAME}-${ENVIRONMENT}"
    
    # Create ECR repository if it doesn't exist
    if ! aws ecr describe-repositories --repository-names "${PROJECT_NAME}-${ENVIRONMENT}" --region $REGION > /dev/null 2>&1; then
        print_message "Creating ECR repository..."
        aws ecr create-repository \
            --repository-name "${PROJECT_NAME}-${ENVIRONMENT}" \
            --region $REGION \
            --image-scanning-configuration scanOnPush=true \
            --image-tag-mutability MUTABLE
    fi
    
    # Push images
    docker push ${ECR_REPO}:latest
    docker push ${ECR_REPO}:${VERSION}
    
    print_success "Images pushed to ECR successfully"
}

# Function to push to DockerHub
push_to_dockerhub() {
    if [ -n "$DOCKERHUB_USERNAME" ]; then
        print_message "Pushing images to DockerHub..."
        
        docker push ${DOCKERHUB_USERNAME}/${PROJECT_NAME}:latest
        docker push ${DOCKERHUB_USERNAME}/${PROJECT_NAME}:${VERSION}
        
        print_success "Images pushed to DockerHub successfully"
    fi
}

# Function to run tests
run_tests() {
    print_message "Running tests..."
    
    # Run Python tests
    if [ -d "tests" ]; then
        python -m pytest tests/ -v
    fi
    
    # Run container health check
    print_message "Testing container health..."
    docker run -d --name test-container -p 8080:8080 ${PROJECT_NAME}:latest
    sleep 10
    
    # Check if container is healthy
    HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' test-container)
    
    if [ "$HEALTH_STATUS" = "healthy" ]; then
        print_success "Container health check passed"
    else
        print_error "Container health check failed"
        docker logs test-container
        docker stop test-container
        docker rm test-container
        exit 1
    fi
    
    # Test API endpoint
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/health)
    
    if [ "$RESPONSE" = "200" ]; then
        print_success "API health check passed"
    else
        print_error "API health check failed"
        docker logs test-container
        docker stop test-container
        docker rm test-container
        exit 1
    fi
    
    # Clean up test container
    docker stop test-container
    docker rm test-container
    
    print_success "All tests passed successfully"
}

# Function to scan image for vulnerabilities
scan_image() {
    print_message "Scanning image for vulnerabilities..."
    
    # Check if Trivy is installed
    if command -v trivy &> /dev/null; then
        trivy image ${PROJECT_NAME}:latest
    else
        print_message "Trivy not installed, skipping vulnerability scan"
        print_message "Install Trivy with: brew install trivy (macOS) or follow instructions at https://aquasecurity.github.io/trivy/"
    fi
}

# Main execution
main() {
    print_message "Starting build process for California Plate Validator v${VERSION}"
    
    # Login to registries
    login_to_ecr
    login_to_dockerhub
    
    # Build image
    build_image
    
    # Run tests
    run_tests
    
    # Scan image
    scan_image
    
    # Push images
    push_to_ecr
    push_to_dockerhub
    
    # Print image information
    print_message "Build completed successfully!"
    print_message "Image tags:"
    echo "  - ${PROJECT_NAME}:latest"
    echo "  - ${PROJECT_NAME}:${VERSION}"
    
    ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
    ECR_REPO="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${PROJECT_NAME}-${ENVIRONMENT}"
    echo "  - ${ECR_REPO}:latest"
    echo "  - ${ECR_REPO}:${VERSION}"
    
    if [ -n "$DOCKERHUB_USERNAME" ]; then
        echo "  - ${DOCKERHUB_USERNAME}/${PROJECT_NAME}:latest"
        echo "  - ${DOCKERHUB_USERNAME}/${PROJECT_NAME}:${VERSION}"
    fi
    
    print_success "Build process completed!"
}

# Handle command line arguments
case "$1" in
    "test")
        run_tests
        ;;
    "scan")
        scan_image
        ;;
    "push")
        push_to_ecr
        push_to_dockerhub
        ;;
    *)
        main
        ;;
esac