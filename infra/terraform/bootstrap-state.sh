#!/bin/bash
# Run this ONCE before terraform init to create the remote state bucket and lock table.
# After this script runs, the S3 backend in providers.tf will work.

set -e

BUCKET="capstone-phoenix-tfstate"
TABLE="capstone-phoenix-tflock"
REGION="us-east-1"

echo "Creating S3 bucket for Terraform state..."
aws s3api create-bucket \
  --bucket "$BUCKET" \
  --region "$REGION" 2>/dev/null || echo "Bucket already exists, skipping."

echo "Enabling versioning on bucket..."
aws s3api put-bucket-versioning \
  --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

echo "Enabling encryption on bucket..."
aws s3api put-bucket-encryption \
  --bucket "$BUCKET" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

echo "Blocking public access on bucket..."
aws s3api put-public-access-block \
  --bucket "$BUCKET" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "Creating DynamoDB table for state locking..."
aws dynamodb create-table \
  --table-name "$TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGION" 2>/dev/null || echo "DynamoDB table already exists, skipping."

echo ""
echo "Done! You can now run:"
echo "  cp terraform.tfvars.example terraform.tfvars  (fill in your IP)"
echo "  terraform init"
echo "  terraform plan"
echo "  terraform apply"
