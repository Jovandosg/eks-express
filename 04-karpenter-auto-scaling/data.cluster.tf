data "terraform_remote_state" "cluster" {
  backend = "s3"

  config = {
    bucket = "nsse-state-files"
    key    = "cluster/terraform.tfstate"
    region = "us-east-1"
  }
}
