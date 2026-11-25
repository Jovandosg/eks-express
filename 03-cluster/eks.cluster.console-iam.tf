# ---------------------------------------------------------------------------
# IAM permissions for the console user to view EKS resources in the AWS Console.
#
# The EKS access entry (in eks.cluster.access.tf) grants Kubernetes RBAC
# permissions. This IAM policy grants the AWS-side read permissions needed to
# navigate to the cluster and call the Kubernetes API from the console.
# ---------------------------------------------------------------------------

resource "aws_iam_policy" "eks_console_access" {
  count       = local.console_user_arn != null ? 1 : 0
  name        = "eks-console-access"
  description = "IAM read permissions for EKS console resource viewing"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:ListAddons",
          "eks:DescribeAddon",
          "eks:ListUpdates",
          "eks:ListFargateProfiles",
          "eks:ListIdentityProviderConfigs",
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the policy to the console IAM user.
# For SSO roles, manage permissions through the IAM Identity Center permission set instead.
resource "aws_iam_user_policy_attachment" "console_user_eks" {
  count      = local.console_user_arn != null && can(regex(":user/", local.console_user_arn)) ? 1 : 0
  user       = split("/", local.console_user_arn)[1]
  policy_arn = aws_iam_policy.eks_console_access[0].arn
}
