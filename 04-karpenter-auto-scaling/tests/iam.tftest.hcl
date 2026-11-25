mock_provider "aws" {}

variables {
  assume_role = {
    role_arn    = "arn:aws:iam::123456789012:role/terraform-role"
    external_id = "test-external-id"
  }
  karpenter = {
    controller_role_name   = "custom-controller"
    controller_policy_name = "custom-controller-policy"
    node_role_name         = "custom-node"
  }
}

override_data {
  target = data.terraform_remote_state.cluster
  values = {
    outputs = {
      Kubernetes_oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/test-cluster"
      Kubernetes_oidc_provider_url = "https://oidc.eks.us-east-1.amazonaws.com/id/test-cluster"
      Kubernetes_cluster_name      = "test-cluster"
    }
  }
}

override_resource {
  target = aws_iam_role.karpenter_node
  values = {
    arn = "arn:aws:iam::123456789012:role/custom-node"
  }
}

override_resource {
  target = aws_iam_policy.karpenter_controller
  values = {
    arn = "arn:aws:iam::123456789012:policy/custom-controller-policy"
  }
}

run "separate_controller_and_node_roles" {
  command = apply

  assert {
    condition = (
      jsondecode(aws_iam_role.karpenter_controller.assume_role_policy).Statement[0].Action == "sts:AssumeRoleWithWebIdentity" &&
      jsondecode(aws_iam_role.karpenter_controller.assume_role_policy).Statement[0].Principal.Federated == data.terraform_remote_state.cluster.outputs.Kubernetes_oidc_provider_arn &&
      jsondecode(aws_iam_role.karpenter_controller.assume_role_policy).Statement[0].Condition.StringEquals == {
        "oidc.eks.us-east-1.amazonaws.com/id/test-cluster:aud" = "sts.amazonaws.com"
        "oidc.eks.us-east-1.amazonaws.com/id/test-cluster:sub" = "system:serviceaccount:kube-system:karpenter"
      }
    )
    error_message = "The controller must trust the cluster OIDC provider only for the kube-system/karpenter ServiceAccount and STS audience."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role.karpenter_node.assume_role_policy).Statement[0].Action == "sts:AssumeRole" &&
      jsondecode(aws_iam_role.karpenter_node.assume_role_policy).Statement[0].Principal.Service == "ec2.amazonaws.com"
    )
    error_message = "The node role must allow EC2 to assume it."
  }

  assert {
    condition = (
      aws_iam_role.karpenter_node.name != aws_iam_role.karpenter_controller.name &&
      alltrue([
        aws_iam_role_policy_attachment.karpenter_node_AmazonEKSWorkerNodePolicy.role == aws_iam_role.karpenter_node.name,
        aws_iam_role_policy_attachment.karpenter_node_AmazonEC2ContainerRegistryReadOnly.role == aws_iam_role.karpenter_node.name,
        aws_iam_role_policy_attachment.karpenter_node_AmazonEKS_CNI_Policy.role == aws_iam_role.karpenter_node.name,
        aws_iam_role_policy_attachment.karpenter_node_AmazonSSMManagedInstanceCore.role == aws_iam_role.karpenter_node.name,
      ])
    )
    error_message = "All worker policies must attach to the dedicated node role, not the controller."
  }

  assert {
    condition = one([
      for statement in jsondecode(aws_iam_policy.karpenter_controller.policy).Statement : statement.Resource
      if statement.Sid == "PassNodeIAMRole"
    ]) == aws_iam_role.karpenter_node.arn
    error_message = "The controller must be allowed to pass the configured node role."
  }

  assert {
    condition = (
      aws_iam_role_policy_attachment.karpenter_controller.role == aws_iam_role.karpenter_controller.name &&
      aws_iam_role_policy_attachment.karpenter_controller.policy_arn == aws_iam_policy.karpenter_controller.arn
    )
    error_message = "The controller policy must be attached to the configured controller role."
  }
}
