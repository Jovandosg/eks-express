locals {
  bash_user_arn    = var.bash_user_arn
  console_user_arn = var.console_user_arn
  eks_oidc_url     = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}