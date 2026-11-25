data "terraform_remote_state" "networking" {
  backend = "s3"

  config = {
    bucket = "nsse-state-files"
    key    = "networking/terraform.tfstate"
    region = "us-east-1"
  }

  lifecycle {
    postcondition {
      condition     = try(length(distinct(self.outputs.private_subnet_id)) >= 2, false)
      error_message = "The networking state must export private_subnet_id with at least two distinct subnet IDs. Apply the networking module first; the subnets must belong to the same VPC and span at least two availability zones."
    }
  }
}
