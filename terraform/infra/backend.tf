terraform {
  backend "s3" {
    bucket         = "jada-tfstate-318675980304" # from bootstrap
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "jada-tf-locks" # from bootstrap
    encrypt        = true
  }
}