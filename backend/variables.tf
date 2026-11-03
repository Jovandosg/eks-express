variable "region" {
  default = "us-east-1"
}

variable "assume_role" {
  type = object({
    role_arn    = string,
    external_id = string
  })

  default = {
    role_arn    = "arn:aws:iam::975050217683:role/terraform-role"
    external_id = "85f49f91-06d9-41c1-94e7-115efce183e9"
  }
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

