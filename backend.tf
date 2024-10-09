terraform {
  backend "s3" {
    bucket = "remote-backend-tf-files"
    key    = "terraform_Sftp_transfer_family_data/terraform.tfstate "
    region = "eu-central-1"
    dynamodb_table = "dynamodb-state-locking"
  }
}
