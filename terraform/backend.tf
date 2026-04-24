terraform {
  backend "s3" {
    bucket       = "project-1-joao-irene-tfstate"
    key          = "project/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}