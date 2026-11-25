variable "region" {
  type    = string
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
  type = object({
    Environment = string
    Project     = string
  })

  default = {
    Environment = "production"
    Project     = "eks-express"
  }
}

variable "karpenter" {
  type = object({
    controller_role_name   = string
    controller_policy_name = string
    node_role_name         = optional(string, "KarpenterNodeRole")
  })
  default = {
    controller_role_name   = "KarpenterControllerRole"
    controller_policy_name = "KarpenterControllerPolicy"
  }
}