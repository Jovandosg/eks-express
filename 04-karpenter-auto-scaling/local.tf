locals {
  eks_cluster_security_group = data.terraform_remote_state.cluster.outputs.Kubernetes_cluster_security_group
  eks_cluster_name  = data.terraform_remote_state.cluster.outputs.Kubernetes_cluster_name
  eks_oidc_provider = data.terraform_remote_state.cluster.outputs.Kubernetes_oidc_provider_arn
  eks_oidc_url      = replace(data.terraform_remote_state.cluster.outputs.Kubernetes_oidc_provider_url, "https://", "")
}
