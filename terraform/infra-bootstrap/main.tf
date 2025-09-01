terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "local" {} # run bootstrap locally
}

provider "aws" { region = var.region }

# S3 bucket for Terraform state (unique name!)
resource "aws_s3_bucket" "tf_state" {
  bucket = var.tf_state_bucket
}
resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locks
resource "aws_dynamodb_table" "tf_lock" {
  name         = var.tf_lock_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}


# GitHub OIDC IdP (create if not exists)
data "aws_iam_openid_connect_provider" "gh" {
  arn = var.gh_oidc_provider_arn
}
# If your account doesn't have it yet, comment the data{} above and use:
# resource "aws_iam_openid_connect_provider" "gh" {
#   url             = "https://token.actions.githubusercontent.com"
#   client_id_list  = ["sts.amazonaws.com"]
#   thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # GitHub OIDC
# }
# Then reference its ARN below.

# IAM role for GitHub Actions (OIDC)
resource "aws_iam_role" "github_tf_role" {
  name = "${var.project}-github-terraform"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Action    = "sts:AssumeRoleWithWebIdentity",
      Principal = { Federated = var.gh_oidc_provider_arn },
      Condition = {
        "StringEquals" = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        },
        "StringLike" = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/${var.github_branch}"
        }
      }
    }]
  })
}

# Least-priv-like policy for our infra (EC2/VPC + state S3/DDB)
data "aws_iam_policy_document" "tf_policy" {
  statement {
    sid     = "TFState"
    actions = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      aws_s3_bucket.tf_state.arn,
      "${aws_s3_bucket.tf_state.arn}/*"
    ]
  }
  statement {
    sid       = "TFStateLock"
    actions   = ["dynamodb:DescribeTable", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = [aws_dynamodb_table.tf_lock.arn]
  }
  statement {
    sid = "BuildVpcAndEc2"
    actions = [
      "ec2:*Vpc*", "ec2:*Subnet*", "ec2:*Route*", "ec2:*InternetGateway*",
      "ec2:*SecurityGroup*", "ec2:RunInstances", "ec2:TerminateInstances",
      "ec2:CreateTags", "ec2:Describe*", "ec2:AssociateAddress", "ec2:AllocateAddress",
      "ec2:CreateKeyPair", "ec2:ImportKeyPair", "ec2:DeleteKeyPair"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "github_tf_policy" {
  name   = "${var.project}-github-terraform-policy"
  policy = data.aws_iam_policy_document.tf_policy.json
}
resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.github_tf_role.name
  policy_arn = aws_iam_policy.github_tf_policy.arn
}

output "state_bucket" { value = aws_s3_bucket.tf_state.bucket }
output "lock_table" { value = aws_dynamodb_table.tf_lock.name }
output "oidc_role_arn" { value = aws_iam_role.github_tf_role.arn }
