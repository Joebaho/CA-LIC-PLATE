# AWS Configuration
aws_region = "us-west-2"
aws_account_id = "123456789012"  # Your AWS Account ID

# Project Configuration
project_name = "california-plate-validator"
environment = "dev"
owner = "DevOps Team"

# Application Configuration
container_port = 8080
container_cpu = 256
container_memory = 512
desired_count = 2
min_capacity = 1
max_capacity = 4

# Network Configuration
vpc_cidr = "10.0.0.0/16"
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
availability_zones = ["us-west-2a", "us-west-2b"]
allowed_cidr_blocks = ["0.0.0.0/0"]

# ECR Configuration
ecr_image_tag_mutability = "MUTABLE"
ecr_scan_on_push = true

# CI/CD Configuration
github_owner = "yourusername"
github_repo_name = "california-plate-validator"
github_branch = "main"
github_token = "ghp_your_github_token_here"  # Replace with your GitHub token
codestar_connection_arn = ""  # Leave empty to create new connection

# Docker Configuration
dockerhub_username = "yourdockerhub"
dockerhub_password = "yourdockerhubpassword"  # Or use access token

# Build Configuration
build_timeout = 30
build_compute_type = "BUILD_GENERAL1_SMALL"

# DNS Configuration (Optional)
create_dns = true
domain_name = "joebahocloud.com"
subdomain = "plates"

# Monitoring Configuration
enable_container_insights = true
log_retention_days = 30

# Security Configuration
enable_alb_ssl = false
certificate_arn = ""  # ARN of ACM certificate for SSL

# Autoscaling Configuration
enable_autoscaling = true
scaling_cpu_threshold = 70
scaling_memory_threshold = 80

# Feature Flags
enable_vpc_endpoints = true
enable_nat_gateway = true
single_nat_gateway = true

# Terraform State Configuration
create_terraform_state_bucket = true
create_terraform_state_lock = true