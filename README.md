# 🚗 California License Plate Validator

A cloud-native application that validates California license plate numbers with a complete CI/CD pipeline on AWS.

## 📋 Features

- **Plate Validation**: Validates California license plates from 1914 to present
- **Multiple Formats**: Supports all historical and modern plate formats
- **RESTful API**: JSON API for programmatic access
- **Web Interface**: Modern, responsive web application
- **Real-time Validation**: Stream validation results
- **Bulk Validation**: Validate multiple plates at once
- **Random Plate Generation**: Generate valid California plates

## 📌 Overview

This project demonstrates a production-grade cloud-native application deployed on AWS using Terraform, Docker, ECS, and CI/CD pipelines. The application validates California license plates via a Flask web interface and is fully automated from infrastructure provisioning to deployment.

## ❓ Problem Statement

Manual application deployments are error-prone, non-scalable, and difficult to maintain. This project solves that by implementing:

**Infrastructure as Code**

**Containerized workloads**

**Automated CI/CD pipelines**

**Scalable and resilient AWS services**

## 🛠 Technology Stack

- Cloud: AWS (ECS, ECR, ALB, VPC, CodePipeline, CodeBuild)

- IaC: Terraform (modular)

- Backend: Python Flask

- Containers: Docker

- CI/CD: AWS CodePipeline

- Version Control: GitHub

## 🏗 Architecture

VPC with public subnets

Application Load Balancer

ECS Fargate service

Docker images stored in ECR

CI/CD pipeline for automated deployments

## 📂 Project Structure

app/            Flask application
docker/         Dockerfile
terraform/      Infrastructure modules
scripts/        Automation scripts

## 🚀 Deployment Instructions

### 📦 Step 1: Clone Repository

```bash
git clone https://github.com/Joebaho/CA-LIC-PLATE.git
cd "CA LIC PLATE"
```

### 🌐 Step 2: Prepare Terraform Backend

Create an S3 bucket for Terraform state:

aws s3 mb s3://my-terraform-state-bucket


Update terraform/backend.tf accordingly.

### 🔧 Step 3: Configure Variables

Edit:

terraform/terraform.tfvars


Set:

AWS region

Project name

CIDR blocks

GitHub repo info (for pipeline)

### 🚀 Step 4: Deploy Infrastructure

```bash
cd terraform
terraform init
terraform validate
terraform plan
terraform apply --auto-approve
```

### 🐳 Step 5: Build & Push Docker Image

```bash
cd ..
chmod +x scripts/build.sh
./scripts/build.sh
```

### 🔁 Step 6: Deploy Application

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

This will:

Push image to ECR

Trigger ECS deployment

Pipeline will handle updates

### 🌍 Step 7: Access the App

Retrieve ALB DNS name from Terraform outputs:

terraform output alb_dns_name


Open in browser.

## 🧹 Destruction

To destroy the entire project type command **terraform destroy** 

```bash
cd terraform
terraform destroy --auto-approve
```


## 🎓 Learning Outcomes

Real-world Terraform modular design

ECS Fargate deployments

CI/CD pipeline automation

Secure cloud architecture practices

End-to-end DevOps workflow

## 📚 Resources

Terraform Docs

AWS ECS Documentation

Docker Best Practices

Flask Documentation

## 🤝 Contribution

Pull requests are welcome. For major changes, please open an issue first.

## 📄 License

MIT License