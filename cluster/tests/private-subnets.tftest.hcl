mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/test-eks-role"
    }
  }
}

override_data {
  target = data.terraform_remote_state.networking
  values = {
    outputs = {
      private_subnet_id = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    }
  }
}

run "cluster_and_nodes_use_private_subnets" {
  command = plan

  assert {
    condition     = toset(aws_eks_cluster.this.vpc_config[0].subnet_ids) == toset(data.terraform_remote_state.networking.outputs.private_subnet_id)
    error_message = "The EKS cluster must use the private subnets exported by networking."
  }

  assert {
    condition     = toset(aws_eks_node_group.this.subnet_ids) == toset(data.terraform_remote_state.networking.outputs.private_subnet_id)
    error_message = "The node group must use the same private subnets as the cluster."
  }
}

run "reject_empty_private_subnets" {
  command = plan

  override_data {
    target = data.terraform_remote_state.networking
    values = {
      outputs = {
        private_subnet_id = []
      }
    }
  }

  expect_failures = [data.terraform_remote_state.networking]
}

run "reject_duplicate_private_subnets" {
  command = plan

  override_data {
    target = data.terraform_remote_state.networking
    values = {
      outputs = {
        private_subnet_id = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef0"]
      }
    }
  }

  expect_failures = [data.terraform_remote_state.networking]
}

run "reject_missing_private_subnet_output" {
  command = plan

  override_data {
    target = data.terraform_remote_state.networking
    values = {
      outputs = {}
    }
  }

  expect_failures = [data.terraform_remote_state.networking]
}
