resource "aws_eks_access_entry" "bash_user" {
  count         = local.bash_user_arn != null ? 1 : 0
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = local.bash_user_arn
  type          = "STANDARD"
}

resource "aws_eks_access_entry" "console_user" {
  count         = local.console_user_arn != null ? 1 : 0
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = local.console_user_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "bash_user" {
  count         = local.bash_user_arn != null ? 1 : 0
  cluster_name  = aws_eks_cluster.this.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = local.bash_user_arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.bash_user]
}

resource "aws_eks_access_policy_association" "console_user" {
  count         = local.console_user_arn != null ? 1 : 0
  cluster_name  = aws_eks_cluster.this.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = local.console_user_arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.console_user]
}