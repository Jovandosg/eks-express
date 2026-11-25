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
variable "console_user_arn" {
  description = "IAM principal ARN for the console/SSO user EKS access entry. Must be a valid IAM user or role ARN that exists in the account. Set to null (or omit) to skip creating the console access entry."
  type        = string
  default     = null

  validation {
    condition     = var.console_user_arn == null || can(regex("^arn:aws:iam::[0-9]{12}:(user/[^/]+|role/.+)$", var.console_user_arn))
    error_message = "console_user_arn must be a valid IAM user or role ARN. Do not use the root account ARN."
  }
}

variable "bash_user_arn" {
  description = "IAM principal ARN for the CLI/Terraform user EKS access entry. Must be a valid IAM user or role ARN that exists in the account. Set to null (or omit) to skip creating the bash access entry."
  type        = string
  default     = null

  validation {
    condition     = var.bash_user_arn == null || can(regex("^arn:aws:iam::[0-9]{12}:(user/[^/]+|role/.+)$", var.bash_user_arn))
    error_message = "bash_user_arn must be a valid IAM user or role ARN."
  }
}

variable "endpoint_public_access" {
  description = "Whether the EKS API server endpoint is publicly accessible. Set to false for production (requires VPN/bastion for kubectl from outside the VPC)."
  type        = bool
  default     = true
}

variable "custom_domain" {
type        = string
default     = "eks.jovando.com.br"
}

variable "endpoint_private_access" {
  description = "Whether the EKS API server endpoint is accessible from within the VPC."
  type        = bool
  default     = true
}

variable "eks_cluster" {
  type = object({
    name                      = string
    role_name                 = string
    version                   = string
    enabled_cluster_log_types = list(string)
    access_config = object({
      authentication_mode = string
    })
    node_group = object({
      name           = string
      role_name      = string
      instance_types = list(string)
      capacity_type  = string
      ami_type       = string
      scaling_config = object({
        desired_size = number
        max_size     = number
        min_size     = number
      })
    })
  })

  validation {
    condition     = contains(["API", "API_AND_CONFIG_MAP", "CONFIG_MAP"], var.eks_cluster.access_config.authentication_mode)
    error_message = "authentication_mode must be one of: API, API_AND_CONFIG_MAP, CONFIG_MAP."
  }

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.eks_cluster.node_group.capacity_type)
    error_message = "capacity_type must be ON_DEMAND or SPOT."
  }

  default = {
    name                      = "eks-express-cluster"
    role_name                 = "eks-express-cluster-role"
    version                   = "1.37"
    enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
    access_config = {
      authentication_mode = "API"
    }
    node_group = {
      name           = "eks-express-node-group"
      role_name      = "eks-express-node-group-role"
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      ami_type       = "AL2023_x86_64_STANDARD"
      scaling_config = {
        desired_size = 3
        max_size     = 3
        min_size     = 3
      }
    }
  }
}
