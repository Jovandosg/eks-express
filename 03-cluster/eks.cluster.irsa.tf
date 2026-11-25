# ---------------------------------------------------------------------------
# IRSA (IAM Roles for Service Accounts) for the VPC CNI addon.
#
# Moves the AmazonEKS_CNI_Policy from the node instance role to a dedicated
# IRSA role scoped to the kube-system:aws-node service account. This prevents
# every pod on the node from inheriting ENI-management permissions.
# ---------------------------------------------------------------------------

# Dedicated IAM role for the VPC CNI daemon set, assumed via OIDC trust.
resource "aws_iam_role" "vpc_cni" {
  name = "${var.eks_cluster.name}-vpc-cni"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Condition = {
          StringEquals = {
            "${local.eks_oidc_url}:sub" = "system:serviceaccount:kube-system:aws-node"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "vpc_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni.name
}

# EKS-managed vpc-cni addon using the IRSA role.
# resolve_conflicts = OVERWRITE transitions from self-managed to EKS-managed.
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  service_account_role_arn    = aws_iam_role.vpc_cni.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}
