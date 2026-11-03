variable "region" {
  default = "us-east-1"
}

variable "assume_role" {
  description = "IAM role to assume (cross-account terraform-role). Provide via terraform.tfvars or TF_VAR_assume_role env var; do not hardcode in version control."
  type = object({
    role_arn    = string
    external_id = string
  })
  sensitive = true
}

variable "tags" {
  type = map(string)
  default = {
    Project     = "not-so-simple-ecommerce"
    Environment = "production"
  }
}


variable "remote_backend" {
  type = object({
    bucket = string
    state_locking = object({
      dynamodb_table_name          = string
      dynamodb_table_billing_mode  = string
      dynamodb_table_hash_key      = string
      dynamodb_table_hash_key_type = string

    })
  })

  default = {
    bucket = "nsse-state-files"
    state_locking = {
      dynamodb_table_name          = "nsse-state-files"
      dynamodb_table_billing_mode  = "PAY_PER_REQUEST"
      dynamodb_table_hash_key      = "LockID"
      dynamodb_table_hash_key_type = "S"
    }
  }
}

