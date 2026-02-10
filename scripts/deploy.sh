#!/bin/bash

# California Plate Validator - Deployment Script
# Deploys infrastructure and application to AWS

set -e

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
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

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Configuration
PROJECT_NAME="california-plate-validator"
ENVIRONMENT=${ENVIRONMENT:-"development"}
REGION=${AWS_DEFAULT_REGION:-"us-west-2"}
TERRAFORM_DIR="terraform"

# Function to check prerequisites
check_prerequisites() {
    print_message "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed"
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured or invalid"
        exit 1
    fi
    
    print_success "All prerequisites met"
}

# Function to initialize Terraform
init_terraform() {
    print_message "Initializing Terraform..."
    
    cd $TERRAFORM_DIR
    
    terraform init \
        -backend-config="bucket=${PROJECT_NAME}-terraform-state" \
        -backend-config="key=terraform.tfstate" \
        -backend-config="region=${REGION}" \
        -backend-config="dynamodb_table=terraform-state-lock" \
        -reconfigure
    
    cd ..
    
    print_success "Terraform initialized"
}

# Function to plan Terraform changes
plan_terraform() {
    print_message "Planning Terraform changes..."
    
    cd $TERRAFORM_DIR
    
    terraform plan \
        -var="environment=${ENVIRONMENT}" \
        -var="aws_region=${REGION}" \
        -out=tfplan
    
    cd ..
    
    print_success "Terraform plan created"
}

# Function to apply Terraform changes
apply_terraform() {
    print_message "Applying Terraform changes..."
    
    cd $TERRAFORM_DIR
    
    terraform apply \
        -var="environment=${ENVIRONMENT}" \
        -var="aws_region=${REGION}" \
        -auto-approve
    
    cd ..
    
    print_success "Terraform changes applied"
}

# Function to destroy infrastructure
destroy_infrastructure() {
    print_warning "This will destroy all infrastructure!"
    read -p "Are you sure? (yes/no): " confirmation
    
    if [ "$confirmation" != "yes" ]; then
        print_message "Destruction cancelled"
        exit 0
    fi
    
    print_message "Destroying infrastructure..."
    
    cd $TERRAFORM_DIR
    
    terraform destroy \
        -var="environment=${ENVIRONMENT}" \
        -var="aws_region=${REGION}" \
        -auto-approve
    
    cd ..
    
    print_success "Infrastructure destroyed"
}

# Function to deploy application
deploy_application() {
    print_message "Deploying application..."
    
    # Build and push Docker image
    ./scripts/build.sh
    
    # Force new deployment in ECS
    if [ "$ENVIRONMENT" != "development" ]; then
        print_message "Triggering ECS service update..."
        
        CLUSTER_NAME="${PROJECT_NAME}-cluster-${ENVIRONMENT}"
        SERVICE_NAME="${PROJECT_NAME}-service-${ENVIRONMENT}"
        
        aws ecs update-service \
            --cluster $CLUSTER_NAME \
            --service $SERVICE_NAME \
            --force-new-deployment \
            --region $REGION
        
        print_message "Waiting for deployment to complete..."
        
        # Wait for service to stabilize
        aws ecs wait services-stable \
            --cluster $CLUSTER_NAME \
            --services $SERVICE_NAME \
            --region $REGION
        
        print_success "Application deployment completed"
    fi
}

# Function to get deployment status
get_status() {
    print_message "Getting deployment status..."
    
    cd $TERRAFORM_DIR
    
    # Get outputs
    ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "Not deployed")
    ECR_REPO=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "Not deployed")
    
    cd ..
    
    print_message "Current deployment status:"
    echo "  Environment: $ENVIRONMENT"
    echo "  Region: $REGION"
    echo "  ALB DNS: $ALB_DNS"
    echo "  ECR Repository: $ECR_REPO"
    
    # Check ECS service status
    if [ "$ALB_DNS" != "Not deployed" ]; then
        print_message "Checking application health..."
        
        # Try to access health endpoint
        HEALTH_URL="http://${ALB_DNS}/api/health"
        
        if curl -s -f $HEALTH_URL > /dev/null; then
            print_success "Application is healthy"
            print_message "Access the application at: http://${ALB_DNS}"
        else
            print_warning "Application health check failed"
        fi
    fi
}

# Function to setup CI/CD pipeline
setup_cicd() {
    print_message "Setting up CI/CD pipeline..."
    
    # Check if CodeStar connection exists
    if ! aws codestar-connections list-connections --region $REGION | grep -q "PENDING"; then
        print_message "Creating GitHub connection for CodePipeline..."
        
        # Create GitHub connection
        CONNECTION_ARN=$(aws codestar-connections create-connection \
            --connection-name "github-connection" \
            --provider-type GitHub \
            --region $REGION \
            --query 'ConnectionArn' \
            --output text)
        
        print_message "GitHub connection created. Please authorize it in the AWS Console"
        print_message "Connection ARN: $CONNECTION_ARN"
    fi
    
    # Update Terraform with connection ARN
    if [ -n "$CONNECTION_ARN" ]; then
        print_message "Updating Terraform with connection ARN..."
        
        cd $TERRAFORM_DIR
        
        terraform apply \
            -var="environment=${ENVIRONMENT}" \
            -var="aws_region=${REGION}" \
            -var="codestar_connection_arn=${CONNECTION_ARN}" \
            -auto-approve
        
        cd ..
    fi
    
    print_success "CI/CD pipeline setup initiated"
}

# Function to view logs
view_logs() {
    print_message "Viewing application logs..."
    
    LOG_GROUP="/ecs/${PROJECT_NAME}-${ENVIRONMENT}"
    
    if aws logs describe-log-groups --log-group-name-prefix $LOG_GROUP --region $REGION &> /dev/null; then
        # Get latest log stream
        LOG_STREAM=$(aws logs describe-log-streams \
            --log-group-name $LOG_GROUP \
            --order-by LastEventTime \
            --descending \
            --max-items 1 \
            --region $REGION \
            --query 'logStreams[0].logStreamName' \
            --output text)
        
        if [ "$LOG_STREAM" != "None" ]; then
            print_message "Latest log stream: $LOG_STREAM"
            
            # Get log events
            aws logs get-log-events \
                --log-group-name $LOG_GROUP \
                --log-stream-name $LOG_STREAM \
                --region $REGION \
                --query 'events[*].message' \
                --output text | tail -50
        else
            print_warning "No log streams found"
        fi
    else
        print_warning "Log group not found"
    fi
}

# Function to run database migrations (if any)
run_migrations() {
    print_message "Running database migrations..."
    # Add database migration commands here if needed
    print_success "Migrations completed"
}

# Main deployment function
main_deployment() {
    print_message "Starting deployment for environment: $ENVIRONMENT"
    
    # Check prerequisites
    check_prerequisites
    
    # Initialize Terraform
    init_terraform
    
    # Plan changes
    plan_terraform
    
    # Apply changes
    apply_terraform
    
    # Deploy application
    deploy_application
    
    # Get status
    get_status
    
    print_success "Deployment completed successfully!"
}

# Handle command line arguments
case "$1" in
    "init")
        check_prerequisites
        init_terraform
        ;;
    "plan")
        check_prerequisites
        plan_terraform
        ;;
    "apply")
        check_prerequisites
        apply_terraform
        ;;
    "destroy")
        destroy_infrastructure
        ;;
    "deploy")
        deploy_application
        ;;
    "status")
        get_status
        ;;
    "logs")
        view_logs
        ;;
    "cicd")
        setup_cicd
        ;;
    "migrate")
        run_migrations
        ;;
    "full")
        main_deployment
        ;;
    *)
        print_message "Usage: $0 {init|plan|apply|destroy|deploy|status|logs|cicd|migrate|full}"
        echo ""
        echo "Commands:"
        echo "  init     - Initialize Terraform"
        echo "  plan     - Plan Terraform changes"
        echo "  apply    - Apply Terraform changes"
        echo "  destroy  - Destroy infrastructure"
        echo "  deploy   - Deploy application only"
        echo "  status   - Get deployment status"
        echo "  logs     - View application logs"
        echo "  cicd     - Setup CI/CD pipeline"
        echo "  migrate  - Run database migrations"
        echo "  full     - Complete deployment"
        exit 1
        ;;
esac