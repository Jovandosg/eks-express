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


variable "vpc" {
  type = object({
    name                     = string
    cidr_block               = string
    internet_gateway_name    = string
    nat_gateway_name         = string
    public_route_table_name  = string
    private_route_table_name = string
    public_subnet = list(object({
      name                    = string
      cidr_block              = string
      availability_zone       = string
      map_public_ip_on_launch = bool

    }))
    private_subnet = list(object({
      name                    = string
      cidr_block              = string
      availability_zone       = string
      map_public_ip_on_launch = bool

    }))
    eip_name             = string
    eks_cluster_name_tag = string
  })

  default = {
    name                     = "nsse-vpc"
    cidr_block               = "10.0.0.0/24"
    internet_gateway_name    = "nsse-internet-gateway"
    public_route_table_name  = "nsse-public-route-table"
    private_route_table_name = "nsse-private-route-table"
    nat_gateway_name         = "nsse-nat-gateway"
    eip_name                 = "nat-gateway-eip"
    eks_cluster_name_tag     = "eks-express-cluster"
    public_subnet = [{
      name                    = "public-subnet-us-east-1a"
      cidr_block              = "10.0.0.0/27"
      availability_zone       = "us-east-1a"
      map_public_ip_on_launch = true
      },
      {
        name                    = "public-subnet-us-east-1b"
        cidr_block              = "10.0.0.64/27"
        availability_zone       = "us-east-1b"
        map_public_ip_on_launch = true
      }
    ]
    private_subnet = [{
      name                    = "private-subnet-us-east-1a"
      cidr_block              = "10.0.0.32/27"
      availability_zone       = "us-east-1a"
      map_public_ip_on_launch = false
      },
      {
        name                    = "private-subnet-us-east-1b"
        cidr_block              = "10.0.0.96/27"
        availability_zone       = "us-east-1b"
        map_public_ip_on_launch = false
      }
    ]
  }
}
