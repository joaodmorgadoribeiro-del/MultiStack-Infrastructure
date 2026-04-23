terraform {
  backend "s3" {
    bucket         = "terraform-state-project1-joao-irene"
    key            = "project/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}