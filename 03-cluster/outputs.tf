output "Kubernetes_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}

output "Kubernetes_oidc_provider_url" {
  value = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "Kubernetes_cluster_name" {
  value = aws_eks_cluster.this.name
}

output "Kubernetes_cluster_security_group" {
  value = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}