terraform {
  backend "s3" {
    bucket         = "vertexchain-terraform-state"
    key            = "vertexchain/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "vertexchain-terraform-locks"
    encrypt        = true
  }
}
