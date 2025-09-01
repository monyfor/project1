variable "project" {
  type    = string
  default = "jada"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "tf_state_bucket" {
  type        = string
  description = "Unique S3 bucket for Terraform state"
}

variable "tf_lock_table" {
  type        = string
  description = "DynamoDB table for Terraform state locking"
}

variable "github_owner" {
  type        = string
  description = "GitHub user/org"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name"
}

variable "github_branch" {
  type    = string
  default = "main"
}

variable "gh_oidc_provider_arn" {
  type        = string
  description = "ARN of the GitHub OIDC provider in this AWS account"
}
