resource "aws_ec2_tag" "cluster_security_group" {
  resource_id = data.terraform_remote_state.cluster.outputs.Kubernetes_cluster_security_group
  key         = "karpenter.sh/discovery"
  value       = local.eks_cluster_name
}