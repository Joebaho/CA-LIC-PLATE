terraform {
  backend "s3" {
    # This will be passed via -backend-config
    # Example: terraform init -backend-config="bucket=my-terraform-state"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}