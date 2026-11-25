resource "helm_release" "load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.14.0"
  namespace = "kube-system"

  set = [
    {
      name  = "clusterName"
      value = aws_eks_cluster.this.id
    },

    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.load_balancer_controller.arn
    },
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    },
    {
      name  = "region"
      value = var.region
    },
    {
      name  = "vpcId"
      value = data.terraform_remote_state.networking.outputs.vpc_id
    },
  ]

  depends_on = [
    aws_iam_role_policy_attachment.load_balancer_controller,
    aws_eks_node_group.this,
    aws_eks_access_policy_association.bash_user,
    aws_eks_access_policy_association.console_user,
  ]
  
  force_update = true
  cleanup_on_fail = true
}

