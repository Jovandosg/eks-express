variable "region" {
  type    = string
  default = "us-east-1"
}

variable "assume_role" {
  type = object({
    role_arn    = string
    external_id = string
  })

  default = {
    role_arn    = "arn:aws:iam::975050217683:role/terraform-role"
    external_id = "85f49f91-06d9-41c1-94e7-115efce183e9"
  }
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
    eip_name = string
  })

  default = {
    name                     = "nsse-vpc"
    cidr_block               = "10.0.0.0/24"
    internet_gateway_name    = "nsse-internet-gateway"
    public_route_table_name  = "nsse-public-route-table"
    private_route_table_name = "nsse-private-route-table"
    nat_gateway_name         = "nsse-nat-gateway"
    eip_name                 = "nat-gateway-eip"
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
