mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_resource "aws_eks_cluster" {
    defaults = {
      identity = [{
        oidc = [{
          issuer = "https://oidc.eks.us-east-1.amazonaws.com/id/test-cluster"
        }]
      }]
    }
  }

  mock_resource "aws_iam_openid_connect_provider" {
    defaults = {
      arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/test-cluster"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/test-eks-role"
    }
  }

  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::123456789012:policy/test-eks-policy"
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

run "irsa_roles_share_cluster_oidc_provider" {
  command = apply

  assert {
    condition     = aws_iam_openid_connect_provider.eks.url == aws_eks_cluster.this.identity[0].oidc[0].issuer
    error_message = "The shared OIDC provider must use the cluster issuer."
  }

  assert {
    condition     = jsondecode(aws_iam_role.vpc_cni.assume_role_policy).Statement[0].Principal.Federated == aws_iam_openid_connect_provider.eks.arn
    error_message = "The VPC CNI role must trust the shared cluster OIDC provider."
  }

  assert {
    condition     = jsondecode(aws_iam_role.container_storage_interface.assume_role_policy).Statement[0].Principal.Federated == aws_iam_openid_connect_provider.eks.arn
    error_message = "The EBS CSI role must trust the shared cluster OIDC provider."
  }
}
